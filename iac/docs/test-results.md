# Test Results — Todo Application Infrastructure

**Date:** 2026-03-13
**Subscription:** DEV-PWR (`f9a02a85-1b41-4628-aaed-9231e993902c`)
**Region:** norwayeast

---

## Test Summary

| Stage | Result | Details |
|-------|--------|---------|
| **1. Syntax Validation** | ✅ Pass | All 6 Bicep files compiled without errors |
| **2. Linting** | ✅ Pass | No warnings or best-practice violations |
| **3. Security Validation** | ✅ Pass | All 7 security checks passed |
| **4. What-If Deployment** | ✅ Pass | 29 resources to create, zero errors |

---

## Stage 1: Syntax Validation

All modules built successfully with `az bicep build`:

| File | Result |
|------|--------|
| `modules/networking.bicep` | ✅ Clean |
| `modules/database.bicep` | ✅ Clean |
| `modules/webapp.bicep` | ✅ Clean |
| `modules/monitoring.bicep` | ✅ Clean |
| `modules/alerts.bicep` | ✅ Clean |
| `main.bicep` | ✅ Clean |

---

## Stage 2: Linting

`az bicep lint --file iac/infra/main.bicep` — no warnings or errors produced.

The only suppressed rule is `no-hardcoded-env-urls` in `database.bicep` for the Private DNS Zone name `privatelink.database.windows.net`, which is correctly suppressed with `#disable-next-line`.

---

## Stage 3: Security Validation

| Check | Status | Location |
|-------|--------|----------|
| SQL Server `publicNetworkAccess: 'Disabled'` | ✅ Pass | `database.bicep` — `publicNetworkAccess: 'Disabled'` |
| Web App managed identity (`systemAssigned: true`) | ✅ Pass | `webapp.bicep` — `managedIdentities: { systemAssigned: true }` |
| NSGs include deny-all inbound rules | ✅ Pass | `networking.bicep` — both `nsgApp` and `nsgPe` have `DenyAllInbound` at priority 4096 |
| Private endpoints configured for SQL | ✅ Pass | `database.bicep` — PE with Private DNS Zone and VNet link |
| No hardcoded secrets | ✅ Pass | Entra-only auth (`azureADOnlyAuthentication: true`), no passwords in code |
| TLS 1.2+ enforced | ✅ Pass | SQL: `minimalTlsVersion: '1.2'`, Web App: `minTlsVersion: '1.2'` |
| All resources tagged | ✅ Pass | All modules receive and apply `tags` parameter to every resource |

---

## Issues Found & Fixed

| # | Issue | File | Fix Applied |
|---|-------|------|-------------|
| 1 | `sqlDatabaseResourceId` output pointed to SQL Server resource ID instead of the database | `modules/database.bicep` | Changed from `sqlServer.outputs.resourceId` to `'${sqlServer.outputs.resourceId}/databases/${sqlDatabaseName}'` to correctly construct the database resource ID |

---

## Stage 4: What-If Deployment

**Command:**
```bash
az deployment sub what-if \
  --location norwayeast \
  --template-file iac/infra/main.bicep \
  --parameters iac/infra/main.bicepparam \
  --parameters sqlAdminObjectId="bdc1bf70-c3ff-4936-bfe8-01f2e6c9d0f2"
```

**Result:** 29 resources to create (all `+ Create`, no modifications or deletions)

### Resources to be Created

| # | Resource Type | Name |
|---|---------------|------|
| 1 | Resource Group | `rg-todo-dev-norwayeast` |
| 2 | Log Analytics Workspace | `law-todo-dev-norwayeast` |
| 3 | Application Insights | `appi-todo-dev-norwayeast` |
| 4 | NSG (App) | `nsg-app-dev-norwayeast` |
| 5 | NSG (PE) | `nsg-pe-dev-norwayeast` |
| 6 | Virtual Network | `vnet-todo-dev-norwayeast` |
| 7 | Subnet (App) | `snet-app-dev-norwayeast` |
| 8 | Subnet (PE) | `snet-pe-dev-norwayeast` |
| 9 | SQL Server | `sql-todo-dev-norwayeast` |
| 10 | SQL Database | `sqldb-todo-dev-norwayeast` |
| 11 | SQL Server Auditing | `default` (audit settings) |
| 12 | Private DNS Zone | `privatelink.database.windows.net` |
| 13 | DNS VNet Link | `vnet-todo-dev-norwayeast-vnetlink` |
| 14 | Private Endpoint | `pep-sql-dev-norwayeast` |
| 15 | PE DNS Zone Group | `default` (DNS zone group) |
| 16 | App Service Plan | `asp-todo-dev-norwayeast` |
| 17 | Web App | `app-todo-dev-norwayeast` |
| 18 | Web App Config | `appsettings` |
| 19–25 | Metric Alerts | CPU, HTTP 5xx, Response Time, Health Check, DTU, Failed Connections, Deadlocks, Storage |
| 26–29 | Diagnostic Settings | App Service, SQL Server, SQL Database logs |

### Key Configuration Verified in What-If Output

- **SQL Server:** `publicNetworkAccess: "Disabled"`, `azureADOnlyAuthentication: true`, `minimalTlsVersion: "1.2"`
- **Web App:** `httpsOnly: true`, VNet integrated to `snet-app-dev-norwayeast`, managed identity enabled
- **NSGs:** Both include `DenyAllInbound` and `DenyAllOutbound` rules at priority 4096
- **Private Endpoint:** Connected to SQL Server via `sqlServer` group, DNS zone properly linked
- **Tags:** All resources include `environment`, `workload`, `owner`, `costCenter`, and `hackathon-team`
