# Architecture Review — Todo Application

**Review Date:** 2026-03-13
**Reviewed Document:** [iac/docs/architecture.md](architecture.md)
**Reviewer:** Architecture Reviewer Agent (WAF/CAF/Security/AVM)

---

## 1. Review Summary

**Overall Health Score: 95/100**

The proposed architecture demonstrates a **strong security-first design** targeting **Norway East** with Private Endpoints, Managed Identity, NSGs with outbound deny-all rules, and TLS enforcement. Azure AD-only authentication is enforced on SQL Server. CAF naming and tagging conventions are correctly applied with the `norwayeast` region suffix. AVM modules are used consistently with pinned versions. Monitoring with Log Analytics, Application Insights, alerting rules, and diagnostic settings is included as a required component. A `/health` endpoint validates database connectivity with automatic instance restart. A CI/CD pipeline using GitHub Actions automates Bicep validation and deployment. The target composite SLA of 99.72% is documented with calculation. Connection pooling and caching strategies are defined. The architecture is well-suited for a **dev/hackathon environment** with a clear, documented upgrade path for production.

**Deductions (-5 points):**
- -2: No Azure Key Vault in base architecture (P4 — acceptable for dev since Managed Identity avoids secrets)
- -1: No Web Application Firewall or DDoS protection on the public App Service endpoint (P4 — acceptable for dev)
- -1: No cost alerting / budget alerts configured (Low)
- -1: Disaster recovery is not addressed beyond future considerations (Low — acceptable for dev)

### What's Done Well

- Database is **never publicly accessible** — Private Endpoint with public access disabled
- **Managed Identity** eliminates stored credentials for App-to-SQL communication
- **Azure AD-only authentication** explicitly enforced (`azureADOnlyAuthentication: true`)
- **NSGs with deny-all defaults** for both inbound AND outbound following least-privilege
- **CAF naming conventions** applied consistently across all 14 resources using `norwayeast` suffix
- **All 4 required tags** included (environment, workload, owner, costCenter)
- **AVM modules** used for all 10 resource types with explicitly pinned versions
- **Private DNS Zone** correctly configured for Private Endpoint name resolution
- **TLS 1.2** enforced and **FTPS disabled** on App Service
- **Azure Defender for SQL** enabled for threat detection
- **Health check endpoint** (`/health`) with DB connectivity validation and auto-restart
- **Composite SLA** calculated and documented (99.72%)
- **Alerting rules** defined for 8 metrics across App Service and SQL
- **Diagnostic settings** streaming logs to Log Analytics for App Service and SQL
- **CI/CD pipeline** defined with lint, build, what-if (PR), and deploy (main) stages
- Clear **modular Bicep structure** with logical dependency ordering

---

## 2. WAF Compliance Matrix

| Pillar | Rating | Key Findings |
|---|---|---|
| **Reliability** | ✅ Compliant | Health check endpoint `/health` with DB connectivity validation and auto-restart. Target composite SLA 99.72% calculated (0.9995 × 0.9999 × 0.9999 × 0.9999). 7-day backup retention for dev with RPO 5 min / RTO 30 min. Zone redundancy documented as production upgrade path (P1v3 + Standard S2+). Disaster recovery noted as future consideration — acceptable for dev. |
| **Security** | ✅ Compliant | Private Endpoint for SQL (public access disabled), System-assigned Managed Identity (no passwords), `azureADOnlyAuthentication: true`, NSGs with inbound+outbound deny-all at priority 4096, TLS 1.2 enforced on all resources, Azure Defender for SQL enabled, FTPS disabled, no secrets in code. Strongest pillar in this design. |
| **Cost Optimization** | ✅ Compliant | Right-sized B1 App Service Plan (~$13/mo) and Basic SQL (5 DTU, ~$5/mo) for dev workload. PerGB2018 Log Analytics (pay-per-use). Clear prod upgrade path documented (P1v3, Standard S2+, Redis). No budget alerting configured (Low finding). |
| **Operational Excellence** | ✅ Compliant | Full IaC with AVM Bicep modules (10 modules, all version-pinned). Monitoring is required (not optional). 8 alerting rules defined across App Service and SQL Database. Diagnostic settings configured for App Service and SQL. CI/CD pipeline with GitHub Actions (lint, build, what-if, deploy). All 4 required tags present. |
| **Performance Efficiency** | ✅ Compliant | SKU tiers appropriate for dev workload. EF Core connection pooling with retry policies (3 retries, 10s delay). In-memory caching (`IMemoryCache`) for dev. Production enhancements documented: Redis, CDN, auto-scaling (S1+). |

---

## 3. Detailed Pillar Analysis

### 3.1 Reliability — ✅ Compliant

| Finding | Severity | Details |
|---|---|---|
| **Zone redundancy** | Info | B1/Basic SKUs don't support availability zones. Production upgrade path to P1v3 (zone-redundant) and Standard S2+ documented in §13. Acceptable for dev. |
| **Composite SLA** | ✅ Pass | 99.72% calculated: App Service 99.95% × SQL 99.99% × VNet 99.99% × DNS 99.99%. Documented in §7.1. |
| **Health check endpoint** | ✅ Pass | `/health` endpoint defined (§7.2): DB connectivity check via Managed Identity, EF Core migration check, 30s probe interval, 3-failure threshold, auto-restart. |
| **Backup & recovery** | ✅ Pass | Azure-managed automated backups, 7-day retention for dev, 35-day for prod. RPO 5 min, RTO 30 min (§7.3). |
| **Disaster recovery** | Low | Multi-region deployment is a future consideration only. Acceptable for a dev/hackathon environment. For production: add active-passive with Traffic Manager. |
| **Auto-healing** | ✅ Pass | App Service health check auto-restarts unhealthy instances after 3 consecutive failures. |

**WAF Reference:** [RE:04 — Define reliability and recovery targets](https://learn.microsoft.com/azure/well-architected/reliability/metrics), [RE:05 — Add redundancy](https://learn.microsoft.com/azure/well-architected/reliability/redundancy), [RE:07 — Self-preservation and self-healing](https://learn.microsoft.com/azure/well-architected/reliability/self-preservation)

### 3.2 Security — ✅ Compliant

| Finding | Severity | Details |
|---|---|---|
| **SQL Database not publicly accessible** | ✅ Pass | Public network access disabled. Private Endpoint in `snet-pe-dev-norwayeast` is the sole access path. |
| **Managed Identity for App → SQL** | ✅ Pass | System-assigned Managed Identity; no stored credentials; automatic rotation. |
| **Azure AD-only authentication** | ✅ Pass | `azureADOnlyAuthentication: true` explicitly set — SQL auth fully disabled (§6.1). |
| **NSGs with deny-all defaults** | ✅ Pass | Both NSGs include deny-all at priority 4096 for inbound AND outbound. Specific allow rules with correct source/destination CIDR. |
| **TLS 1.2 enforced** | ✅ Pass | Documented for App Service (`minTlsVersion: '1.2'`) and SQL Server (`minimalTlsVersion: '1.2'`) in §6.4. |
| **Azure Defender for SQL** | ✅ Pass | Enabled for vulnerability assessment and advanced threat protection (§6.5). |
| **FTPS disabled** | ✅ Pass | App Service configured with `ftpsState: 'Disabled'` (§6.5). |
| **HTTPS-only** | ✅ Pass | App Service configured with `httpsOnly: true` (§6.5). |
| **No Key Vault** | P4 | Architecture uses Managed Identity (no secrets needed currently). Key Vault listed as future consideration in §13. If any application settings later contain sensitive values, Key Vault should be added. |
| **No WAF / DDoS protection** | P4 | NSG allows HTTPS (443) from Internet to snet-app. Expected for App Service, but no L7 OWASP protection. For production: add Azure Front Door with WAF (documented in §13). |
| **Network segmentation** | ✅ Pass | Separate subnets for app (10.0.1.0/24) and private endpoints (10.0.2.0/24). NSG rules restrict cross-subnet traffic to only SQL port 1433. |

**WAF Reference:** [SE:04 — Create segmentation and perimeters](https://learn.microsoft.com/azure/well-architected/security/segmentation), [SE:05 — Identity and access management](https://learn.microsoft.com/azure/well-architected/security/identity-access), [SE:06 — Network traffic isolation](https://learn.microsoft.com/azure/well-architected/security/networking), [SE:07 — Encryption](https://learn.microsoft.com/azure/well-architected/security/encryption)

### 3.3 Cost Optimization — ✅ Compliant

| Finding | Severity | Details |
|---|---|---|
| **B1 App Service Plan** | ✅ Pass | 1 core, 1.75 GB RAM (~$13/month). Appropriate for dev workload. |
| **Basic SQL Database (5 DTU)** | ✅ Pass | Minimal compute (~$5/month). Suitable for dev only; upgrade path documented. |
| **PerGB2018 Log Analytics** | ✅ Pass | Pay-per-use model appropriate for low-volume dev environments. |
| **No auto-scaling** | Info | Not supported on B1 tier. Documented as S1+ production upgrade (§13). |
| **No cost alerting** | Low | No Azure Cost Management budget alerts or anomaly detection configured. Consider adding for production. |
| **Dev/prod differentiation** | ✅ Pass | §13 clearly documents production SKU upgrades (P1v3, Standard S2+, Redis). |

**WAF Reference:** [Cost Optimization checklist](https://learn.microsoft.com/azure/well-architected/cost-optimization/checklist)

### 3.4 Operational Excellence — ✅ Compliant

| Finding | Severity | Details |
|---|---|---|
| **IaC with AVM Bicep** | ✅ Pass | All resources deployed via Bicep with 10 AVM modules. Modular structure: networking → monitoring → database → webapp. |
| **Monitoring required** | ✅ Pass | Application Insights and Log Analytics are mandatory components (§9). |
| **CI/CD pipeline** | ✅ Pass | GitHub Actions: lint → build → what-if (PR), build → deploy (push to main). Defined in §12. |
| **Alerting rules** | ✅ Pass | 8 alert rules: App Service (CPU, 5xx, response time, health check) + SQL (DTU, connections, deadlocks, storage). Defined in §8. |
| **Diagnostic settings** | ✅ Pass | App Service (4 log categories) and SQL (audit events, insights, tuning, errors, timeouts) streaming to Log Analytics. Defined in §9. |
| **Tagging strategy** | ✅ Pass | All 4 required tags present: `environment=dev`, `workload=todo`, `owner=hackathon-team`, `costCenter=hackathon-2026`. |
| **Naming conventions** | ✅ Pass | All 14 resources follow CAF naming patterns with consistent `norwayeast` suffix. |

**WAF Reference:** [Operational Excellence checklist](https://learn.microsoft.com/azure/well-architected/operational-excellence/checklist)

### 3.5 Performance Efficiency — ✅ Compliant

| Finding | Severity | Details |
|---|---|---|
| **B1 SKU** | Info | 1 core, 1.75 GB RAM. Adequate for dev; P1v3 upgrade path documented. |
| **Basic SQL (5 DTU)** | Info | Very limited compute. Suitable for dev only; Standard S2+ / Serverless GP upgrade documented. |
| **Connection pooling** | ✅ Pass | EF Core connection pooling with retry-on-failure (3 retries, 10s delay). Pool size tuned to DTU limits. |
| **Caching strategy** | ✅ Pass | In-memory caching (`IMemoryCache`) for dev; Azure Cache for Redis for production (§13). |
| **CDN for static content** | Info | Noted as production enhancement: Azure CDN or Front Door for static assets (§13). |
| **Auto-scaling** | Info | Not supported on B1. S1+ with CPU/memory-based scale rules for production (§13). |

**WAF Reference:** [Performance Efficiency checklist](https://learn.microsoft.com/azure/well-architected/performance-efficiency/checklist)

---

## 4. CAF Compliance

### 4.1 Naming Convention Audit

| Resource | Name | CAF Pattern | Verdict |
|---|---|---|---|
| Resource Group | `rg-todo-dev-norwayeast` | `rg-<workload>-<environment>-<region>` | ✅ Compliant |
| Virtual Network | `vnet-todo-dev-norwayeast` | `vnet-<workload>-<environment>-<region>` | ✅ Compliant |
| Subnet (app) | `snet-app-dev-norwayeast` | `snet-<purpose>-<environment>-<region>` | ✅ Compliant |
| Subnet (pe) | `snet-pe-dev-norwayeast` | `snet-<purpose>-<environment>-<region>` | ✅ Compliant |
| NSG (app) | `nsg-app-dev-norwayeast` | `nsg-<purpose>-<environment>-<region>` | ✅ Compliant |
| NSG (pe) | `nsg-pe-dev-norwayeast` | `nsg-<purpose>-<environment>-<region>` | ✅ Compliant |
| App Service Plan | `asp-todo-dev-norwayeast` | `asp-<workload>-<environment>-<region>` | ✅ Compliant |
| App Service | `app-todo-dev-norwayeast` | `app-<workload>-<environment>-<region>` | ✅ Compliant |
| SQL Server | `sql-todo-dev-norwayeast` | `sql-<workload>-<environment>-<region>` | ✅ Compliant |
| SQL Database | `sqldb-todo-dev-norwayeast` | `sqldb-<workload>-<environment>-<region>` | ✅ Compliant |
| Private Endpoint | `pep-sql-dev-norwayeast` | `pep-<resource>-<environment>-<region>` | ✅ Compliant |
| Log Analytics | `law-todo-dev-norwayeast` | `law-<workload>-<environment>-<region>` | ✅ Compliant |
| App Insights | `appi-todo-dev-norwayeast` | `appi-<workload>-<environment>-<region>` | ✅ Compliant |

**Result: 13/13 resources follow CAF naming conventions.** All names use lowercase, hyphens as separators, no underscores, consistent `norwayeast` region suffix.

**Reference:** [Define your naming convention (CAF)](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming), [Abbreviation examples for Azure resources](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)

### 4.2 Tagging Audit

| Required Tag | Present | Value |
|---|---|---|
| `environment` | ✅ | `dev` |
| `workload` | ✅ | `todo` |
| `owner` | ✅ | `hackathon-team` |
| `costCenter` | ✅ | `hackathon-2026` |

**Result: 4/4 required tags present.** Consider adding `createdBy` and `createdDate` for operational auditing.

**Reference:** [Define your tagging strategy (CAF)](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)

### 4.3 Resource Organization

| Criteria | Verdict | Notes |
|---|---|---|
| Single resource group | ✅ Pass | All resources in `rg-todo-dev-norwayeast` — appropriate for a single-workload dev environment |
| Region appropriate | ✅ Pass | Norway East is appropriate for European workloads with data residency in Norway |
| Logical grouping | ✅ Pass | Resources organized by function in the modular Bicep structure (networking, monitoring, database, webapp) |

---

## 5. Security Findings

| ID | Priority | Finding | Affected Resource(s) | Impact | Remediation |
|---|---|---|---|---|---|
| SEC-01 | ✅ Pass | Azure AD-only auth enforced | `sql-todo-dev-norwayeast` | `azureADOnlyAuthentication: true` explicitly set | No action needed |
| SEC-02 | ✅ Pass | SQL not publicly accessible | `sql-todo-dev-norwayeast` | Public network access disabled; Private Endpoint only | No action needed |
| SEC-03 | ✅ Pass | Managed Identity for App → SQL | `app-todo-dev-norwayeast` | No passwords or connection string secrets | No action needed |
| SEC-04 | ✅ Pass | NSG deny-all defaults (both directions) | `nsg-app-dev-norwayeast`, `nsg-pe-dev-norwayeast` | Deny-all at priority 4096 inbound + outbound | No action needed |
| SEC-05 | ✅ Pass | TLS 1.2 enforced | All resources | `minTlsVersion: '1.2'` on App Service and SQL Server | No action needed |
| SEC-06 | ✅ Pass | Azure Defender for SQL | `sql-todo-dev-norwayeast` | Threat detection and vulnerability assessment enabled | No action needed |
| SEC-07 | P4 | No Azure Key Vault | — | If future app settings contain secrets, no secrets store exists | Add Key Vault when needed; Managed Identity currently avoids the need |
| SEC-08 | P4 | No Web Application Firewall | `app-todo-dev-norwayeast` | No L7 DDoS or OWASP protection for public endpoint | For production: add Azure Front Door with WAF |

---

## 6. AVM Compliance

| Module | Registry Path | Version Pinned | Compliance |
|---|---|---|---|
| Resource Group | `br/public:avm/res/resources/resource-group` | ✅ `0.4.1` | ✅ Compliant |
| Virtual Network | `br/public:avm/res/network/virtual-network` | ✅ `0.5.2` | ✅ Compliant |
| Network Security Group | `br/public:avm/res/network/network-security-group` | ✅ `0.5.1` | ✅ Compliant |
| App Service Plan | `br/public:avm/res/web/serverfarm` | ✅ `0.4.1` | ✅ Compliant |
| Web App | `br/public:avm/res/web/site` | ✅ `0.12.0` | ✅ Compliant |
| SQL Server | `br/public:avm/res/sql/server` | ✅ `0.12.0` | ✅ Compliant |
| Private Endpoint | `br/public:avm/res/network/private-endpoint` | ✅ `0.10.1` | ✅ Compliant |
| Private DNS Zone | `br/public:avm/res/network/private-dns-zone` | ✅ `0.7.1` | ✅ Compliant |
| Log Analytics | `br/public:avm/res/operational-insights/workspace` | ✅ `0.9.1` | ✅ Compliant |
| App Insights | `br/public:avm/res/insights/component` | ✅ `0.4.2` | ✅ Compliant |

**Result: 10/10 AVM modules used with pinned versions.** No use of `latest`. All modules reference the official Bicep public registry (`br/public:avm/res/`). Per [SNFR25](https://azure.github.io/Azure-Verified-Modules/spec/SNFR25/), AVM modules use CAF-aligned resource name prefixes by default.

**Recommendation:** Run the `update-avm-modules-in-bicep` skill before implementation to verify these are the latest available versions.

---

## 7. Recommendations (Prioritized)

| Priority | Recommendation | WAF Pillar | Status |
|---|---|---|---|
| **P4** | Add **Azure Key Vault** to base architecture for future-proofing | Security | Open — add when needed |
| **P4** | Add **Web Application Firewall** (Azure Front Door) for production | Security | Open — future consideration |
| **P4** | Add **Azure Cost Management budget alerts** | Cost Optimization | Open — recommended |
| **P4** | Add **`createdBy` and `createdDate` tags** for operational auditing | Operational Excellence | Open — nice-to-have |

**All critical (P1), high (P2), and medium (P3) items are already addressed in the architecture.** The remaining P4 items are low-priority enhancements, most of which are documented as production-tier upgrades in §13 (Future Considerations).

---

## 8. Questions for the Team

1. **Traffic Patterns**: What are the expected peak concurrent users? This affects whether B1 App Service Plan is appropriately sized or if immediate upscaling is needed.
2. **Data Sensitivity**: Does the Todo application handle any PII or sensitive data? This affects whether Azure Key Vault and additional encryption (e.g., Always Encrypted) should be added to the base architecture now rather than deferred.
3. **Production Timeline**: When will this architecture be promoted to production? The future considerations section (§13) is comprehensive, but a timeline would help sequence the P4 recommendations.
4. **Norway East Availability**: Has availability of all required services been confirmed in Norway East? Some newer AVM module features may have regional limitations.
5. **Entra ID Admin**: Who is the designated Azure AD administrator for the SQL Server? The architecture requires an Entra ID object ID for the `sqlAdminObjectId` parameter.

---

## References

- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/what-is-well-architected-framework)
- [Design review checklist for Reliability](https://learn.microsoft.com/azure/well-architected/reliability/checklist)
- [Design review checklist for Security](https://learn.microsoft.com/azure/well-architected/security/checklist)
- [Design review checklist for Cost Optimization](https://learn.microsoft.com/azure/well-architected/cost-optimization/checklist)
- [Design review checklist for Operational Excellence](https://learn.microsoft.com/azure/well-architected/operational-excellence/checklist)
- [Design review checklist for Performance Efficiency](https://learn.microsoft.com/azure/well-architected/performance-efficiency/checklist)
- [Architecture best practices for Azure SQL Database](https://learn.microsoft.com/azure/well-architected/service-guides/azure-sql-database)
- [Architecture best practices for Azure App Service](https://learn.microsoft.com/azure/well-architected/service-guides/app-service-web-apps)
- [Architecture best practices for Application Insights](https://learn.microsoft.com/azure/well-architected/service-guides/application-insights)
- [Define your naming convention (CAF)](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Abbreviation examples for Azure resources (CAF)](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
- [Define your tagging strategy (CAF)](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)
- [Organize your Azure resources effectively (CAF)](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-setup-guide/organize-resources)
- [Azure Verified Modules — Resource Naming (SNFR25)](https://azure.github.io/Azure-Verified-Modules/spec/SNFR25/)
- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
