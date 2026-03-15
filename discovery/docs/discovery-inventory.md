# Discovery Inventory — rg-dev-ai-sdc-02

## 1. Discovery Summary

| Field | Value |
|-------|-------|
| **Subscription Name** | DEV-PWR |
| **Subscription ID** | `f9a02a85-1b41-4628-aaed-9231e993902c` |
| **Tenant ID** | `b07a7915-757b-48fe-a25b-e3da9e84df61` |
| **Resource Group** | `rg-dev-ai-sdc-02` |
| **Scan Date** | 2026-03-14 |
| **Scan Performed By** | GitHub Copilot Discoverer Agent |
| **Total Resources Found** | 11 |

### Resource Count by Type

| Resource Type | Count |
|---------------|-------|
| Microsoft.App/containerApps | 1 |
| Microsoft.App/managedEnvironments | 1 |
| Microsoft.Bing/accounts | 1 |
| Microsoft.CognitiveServices/accounts | 1 |
| Microsoft.CognitiveServices/accounts/projects | 1 |
| Microsoft.ContainerRegistry/registries | 1 |
| Microsoft.OperationalInsights/workspaces | 2 |
| microsoft.insights/components | 1 |
| microsoft.insights/actiongroups | 1 |
| Microsoft.Search/searchServices | 1 |
| **TOTAL** | **11** |

---

## 2. Resource Group Overview

| Name | Location | Tags | Provisioning State | Notes |
|------|----------|------|--------------------|-------|
| `rg-dev-ai-sdc-02` | Sweden Central | ❌ None | Succeeded | AI workload resource group |

> **CAF Gap**: Resource group has no tags (`environment`, `workload`, `owner`, `costCenter` are missing).

---

## 3. Detailed Resource Inventory

### 3.1 Compute — Container Apps

#### `ca-ai-dev-sdc-02` — Azure Container App

| Property | Value |
|----------|-------|
| **Type** | Microsoft.App/containerApps |
| **Location** | Sweden Central |
| **SKU / Tier** | Consumption (workloadProfileName: null) |
| **Tags** | `azd-service-name=mcp-server` |
| **Provisioning State** | Succeeded |
| **Running Status** | Running |
| **Managed Identity** | ❌ None |
| **External Ingress** | ✅ Enabled (public HTTPS) |
| **FQDN** | `ca-ai-dev-sdc-02.lemongrass-afc621ac.swedencentral.azurecontainerapps.io` |
| **Target Port** | 8000 |
| **Transport** | Auto (HTTP/1.1 or HTTP/2) |
| **Allow Insecure** | false |
| **Image** | `craiddevsdc02.azurecr.io/my-python-mcp/mcp-server-environment-mcp:azd-deploy-1771930217` |
| **CPU** | 0.5 vCPU |
| **Memory** | 1 GiB |
| **Min Replicas** | 0 (scales to zero) |
| **Max Replicas** | 3 |
| **Scale Rules** | ❌ None (no auto-scale triggers) |
| **Active Revisions Mode** | Single |
| **Registry Auth** | ⚠️ Username/Password (`craiddevsdc02` admin user) |
| **Secrets** | `azure-client-id`, `azure-client-secret`, `azure-tenant-id`, `azure-scope`, `registry-password` |
| **Created By** | alberto.aguzzi@evides.nl |
| **Last Modified** | 2026-02-24 |

> **Security Risk**: No managed identity — the app authenticates to Azure services using a service principal client secret stored as a Container App secret. Admin credentials are also used for ACR pull.

---

#### `cae-ai-dev-sdc-02` — Container Apps Managed Environment

| Property | Value |
|----------|-------|
| **Type** | Microsoft.App/managedEnvironments |
| **Location** | Sweden Central |
| **Tags** | ❌ None |
| **Provisioning State** | Succeeded |
| **Default Domain** | `lemongrass-afc621ac.swedencentral.azurecontainerapps.io` |
| **Static IP** | `135.116.0.47` |
| **Zone Redundant** | ❌ No |
| **VNet Integration** | ❌ None (vnetConfiguration: null) |
| **Public Network Access** | ✅ Enabled |
| **mTLS (peer authentication)** | ❌ Disabled |
| **Peer Traffic Encryption** | ❌ Disabled |
| **App Logs Destination** | Log Analytics (`law-ai-dev-sdc-02-uzbv7zkmlm562`) |
| **Workload Profiles** | Consumption only |
| **KEDA Version** | 2.17.2 |
| **Dapr Version** | 1.13.6-msft.6 |

---

### 3.2 AI & Cognitive Services

#### `res-ai-dev-sdc-02` — Azure AI Services

| Property | Value |
|----------|-------|
| **Type** | Microsoft.CognitiveServices/accounts |
| **Kind** | AIServices |
| **Location** | Sweden Central |
| **SKU** | S0 |
| **Tags** | ❌ None |
| **Provisioning State** | Succeeded |
| **Endpoint** | `https://res-ai-dev-sdc-02.cognitiveservices.azure.com/` |
| **Managed Identity** | ✅ System-Assigned (`41a6ae74-39ca-47d8-9268-aff046257a7e`) |
| **Public Network Access** | ⚠️ Enabled |
| **Network ACL Default Action** | ⚠️ Allow (no IP restrictions) |
| **Disable Local Auth (API keys)** | ❌ No (API keys still active) |
| **Min TLS Version** | ❌ Not explicitly set |
| **Restrict Outbound Network** | Not configured |

---

#### `res-ai-dev-sdc-02/proj-ai-dev-sdc-02` — AI Foundry Project

| Property | Value |
|----------|-------|
| **Type** | Microsoft.CognitiveServices/accounts/projects |
| **Kind** | AIServices |
| **Location** | Sweden Central |
| **Tags** | ❌ None |
| **Provisioning State** | Succeeded |
| **Managed Identity** | ✅ System-Assigned (`b343e71a-0cb6-49c0-aa60-dc7c8300100e`) |

---

### 3.3 AI Search

#### `srch-ai-dev-sdc-02` — Azure AI Search

| Property | Value |
|----------|-------|
| **Type** | Microsoft.Search/searchServices |
| **Location** | Sweden Central |
| **SKU** | Free |
| **Tags** | ❌ None (empty `{}`) |
| **Status** | Running |
| **Public Network Access** | ⚠️ Enabled |
| **Auth Options** | ⚠️ API Keys only (`apiKeyOnly`) |
| **Disable Local Auth** | ❌ No |
| **Replica Count** | 1 |
| **Partition Count** | 1 |
| **Private Endpoints** | ❌ None |
| **Shared Private Link Resources** | ❌ None |
| **Semantic Search** | Free tier |
| **IP Rules** | ❌ None |
| **Network Bypass** | None |
| **Upgrade Available** | Not available (Free tier) |

---

### 3.4 Container Registry

#### `craiddevsdc02` — Azure Container Registry

| Property | Value |
|----------|-------|
| **Type** | Microsoft.ContainerRegistry/registries |
| **Location** | Sweden Central |
| **SKU** | Basic |
| **Tags** | ❌ None (empty `{}`) |
| **Provisioning State** | Succeeded |
| **Login Server** | `craiddevsdc02.azurecr.io` |
| **Admin User Enabled** | ⚠️ Yes |
| **Public Network Access** | ⚠️ Enabled |
| **Network Rule Set** | ❌ None |
| **Created By** | alberto.aguzzi@evides.nl |
| **Last Modified** | 2026-02-24 |

> **Security Risk**: Admin user is enabled and is actively used by the Container App for image pull (username/password auth). Best practice is to use managed identity for ACR pull.

---

### 3.5 Bing Grounding

#### `bng-ai-dev-gbl-02` — Bing Grounding Account

| Property | Value |
|----------|-------|
| **Type** | Microsoft.Bing/accounts |
| **Kind** | Bing.Grounding |
| **Location** | Global |
| **SKU** | G1 |
| **Tags** | ❌ None (empty `{}`) |
| **Provisioning State** | Succeeded |

---

### 3.6 Monitoring

#### `law-ai-dev-sdc-02-uzbv7zkmlm562` — Log Analytics Workspace (AZD-deployed)

| Property | Value |
|----------|-------|
| **Type** | Microsoft.OperationalInsights/workspaces |
| **Location** | Sweden Central |
| **SKU** | PerGB2018 |
| **Retention** | 30 days |
| **Tags** | ❌ None |
| **Provisioning State** | Succeeded |
| **Connected To** | Container Apps Environment (`cae-ai-dev-sdc-02`) |
| **Created By** | alberto.aguzzi@evides.nl (via `azd`) |

---

#### `log-ai-dev-sdc-02` — Log Analytics Workspace (manually deployed)

| Property | Value |
|----------|-------|
| **Type** | Microsoft.OperationalInsights/workspaces |
| **Location** | Sweden Central |
| **SKU** | PerGB2018 |
| **Retention** | 30 days |
| **Tags** | ❌ None (empty `{}`) |
| **Provisioning State** | Succeeded |
| **Workspace ID** | `4e9b7c5f-cc6d-4561-bd9c-eb233867525d` |
| **Connected To** | Application Insights (`appi-ai-dev-sdc-02`) |

> **Operational Gap**: Two separate Log Analytics workspaces exist. This creates fragmented observability — Container App logs and Application Insights telemetry are stored in different workspaces.

---

#### `appi-ai-dev-sdc-02` — Application Insights

| Property | Value |
|----------|-------|
| **Type** | microsoft.insights/components |
| **Kind** | web |
| **Location** | Sweden Central |
| **Tags** | ❌ None (empty `{}`) |
| **Application Type** | web |
| **Sampling Percentage** | Not configured (100% / disabled) |
| **Workspace Resource ID** | `log-ai-dev-sdc-02` |
| **Public Network Ingestion** | ⚠️ Enabled |
| **Public Network Query** | ⚠️ Enabled |

---

#### `Application Insights Smart Detection` — Action Group

| Property | Value |
|----------|-------|
| **Type** | microsoft.insights/actiongroups |
| **Location** | Global |
| **Tags** | ❌ None |
| **Note** | Auto-created by Application Insights Smart Detection |

---

## 4. Network Topology Summary

```
Internet
    │
    ▼ (HTTPS, public)
ca-ai-dev-sdc-02 (Container App)
    │ hosted in
    ▼
cae-ai-dev-sdc-02 (Container Apps Managed Environment)
    │ no VNet integration — runs on Microsoft-managed infrastructure
    │
    ├──► craiddevsdc02.azurecr.io (ACR - public, admin auth)
    ├──► res-ai-dev-sdc-02.cognitiveservices.azure.com (AI Services - public)
    └──► srch-ai-dev-sdc-02.search.windows.net (AI Search - public)
```

| Item | Value |
|------|-------|
| **Virtual Networks** | ❌ None |
| **Subnets** | ❌ None |
| **Network Security Groups** | ❌ None |
| **Private Endpoints** | ❌ None |
| **VNet Integration (Container Apps)** | ❌ None |
| **Public IPs (dedicated)** | Container Apps Env static IP: `135.116.0.47` |
| **Outbound IPs (Container App)** | `20.240.16.137` |
| **Load Balancers** | ❌ None (managed by Container Apps platform) |
| **DNS Zones** | ❌ None (using Azure default DNS) |
| **Firewall** | ❌ None |

> **Architecture Note**: This is a fully cloud-native, internet-facing AI application. All services communicate over public endpoints. There is no network perimeter. The Container Apps Environment is not VNet-injected.

---

## 5. Security Snapshot

### 5.1 Public Endpoints

| Resource | Public Endpoint | Risk Level |
|----------|----------------|------------|
| `ca-ai-dev-sdc-02` | `https://ca-ai-dev-sdc-02.lemongrass-afc621ac.swedencentral.azurecontainerapps.io` | ⚠️ Medium — intended public endpoint (MCP server) |
| `craiddevsdc02` (ACR) | `craiddevsdc02.azurecr.io` | ⚠️ Medium — public registry, admin user enabled |
| `res-ai-dev-sdc-02` (AI Services) | `https://res-ai-dev-sdc-02.cognitiveservices.azure.com/` | ⚠️ Medium — no IP allowlist |
| `srch-ai-dev-sdc-02` (AI Search) | `https://srch-ai-dev-sdc-02.search.windows.net` | ⚠️ Medium — API keys only, no IP restrictions |
| `appi-ai-dev-sdc-02` (App Insights) | Public ingestion & query | ⚠️ Low — standard for App Insights |

### 5.2 Managed Identity Usage

| Resource | Identity Type | Principal ID | Notes |
|----------|--------------|-------------|-------|
| `res-ai-dev-sdc-02` | System-Assigned | `41a6ae74-39ca-47d8-9268-aff046257a7e` | ✅ Present |
| `res-ai-dev-sdc-02/proj-ai-dev-sdc-02` | System-Assigned | `b343e71a-0cb6-49c0-aa60-dc7c8300100e` | ✅ Present |
| `ca-ai-dev-sdc-02` | ❌ None | — | ❌ Uses service principal client secret |
| `craiddevsdc02` | ❌ None | — | ACR does not support identity directly |
| `srch-ai-dev-sdc-02` | ❌ None | — | ❌ API keys only |

### 5.3 Secrets & Credential Management

| Secret | Location | Risk |
|--------|----------|------|
| `azure-client-id` | Container App secret | ⚠️ Service principal credentials stored in Container App config |
| `azure-client-secret` | Container App secret | ❌ High — plain client secret, no Key Vault |
| `azure-tenant-id` | Container App secret | ⚠️ Low — not sensitive, but should use env var |
| `azure-scope` | Container App secret | ⚠️ Low |
| `registry-password` | Container App secret | ⚠️ Medium — ACR admin password |

> **Critical Gap**: No Azure Key Vault present. All secrets are stored directly as Container App secrets. The `azure-client-secret` represents a standing credential with no expiry enforcement visible.

### 5.4 Key Vault

| Item | Status |
|------|--------|
| Key Vault present | ❌ None found in resource group |

### 5.5 Diagnostic Settings Coverage

| Resource | Diagnostic Settings |
|----------|-------------------|
| `ca-ai-dev-sdc-02` | ❌ Not configured (logs via Container Apps platform to LAW) |
| `res-ai-dev-sdc-02` | ❌ Not configured |
| `srch-ai-dev-sdc-02` | ❌ Not configured |
| `craiddevsdc02` | ❌ Not configured |
| `cae-ai-dev-sdc-02` | ✅ Platform logs → `law-ai-dev-sdc-02-uzbv7zkmlm562` |
| `appi-ai-dev-sdc-02` | ✅ Linked to `log-ai-dev-sdc-02` workspace |

---

## 6. RBAC Overview (Inherited from Subscription)

| Principal | Type | Role | Scope Note |
|-----------|------|------|-----------|
| `azure@evides.nl` | User | Owner | Inherited |
| `m.super@evides.nl` | User | Contributor | Inherited |
| `r.wanninkhof_aumatics.nl` | External User | Contributor | Inherited (B2B) |
| `B2B.Role.Aumatics_DevOps_Engineers` | Group | Contributor | Inherited |
| `B2B.Role.Aumatics_Architects` | Group | Contributor | Inherited |
| `AZR-IAM-DEV-PWR-Contributor` | Group | Contributor | Inherited |
| `AZR-IAM-DEV-PWR-Reader` | Group | Reader | Inherited |
| Multiple Owner ServicePrincipals | ServicePrincipal | Owner | Inherited (pipelines/automation) |
| Orca Security DSPM Scanner | ServicePrincipal | Reader + custom | Inherited (security scanning) |

> **Note**: No resource-group-scoped role assignments exist. All access is inherited from the subscription level.

---

## 7. CAF / Tagging Compliance

| Resource | CAF Name Compliant | Tags Present | Notes |
|----------|--------------------|-------------|-------|
| `rg-dev-ai-sdc-02` | ⚠️ Partial (no `env` suffix pattern) | ❌ None | Missing standard CAF tags |
| `ca-ai-dev-sdc-02` | ✅ Good | ⚠️ Partial (`azd-service-name` only) | Missing `environment`, `workload`, `owner`, `costCenter` |
| `cae-ai-dev-sdc-02` | ✅ Good | ❌ None | Missing all tags |
| `res-ai-dev-sdc-02` | ✅ Good | ❌ None | Missing all tags |
| `craiddevsdc02` | ⚠️ No hyphens (ACR constraint) | ❌ None | ACR names can't contain hyphens |
| `law-ai-dev-sdc-02-uzbv7zkmlm562` | ⚠️ Random suffix (azd-generated) | ❌ None | AZD appends unique suffix |
| `log-ai-dev-sdc-02` | ✅ Good | ❌ None | Missing all tags |
| `appi-ai-dev-sdc-02` | ✅ Good | ❌ None | Missing all tags |
| `srch-ai-dev-sdc-02` | ✅ Good | ❌ None | Missing all tags |
| `bng-ai-dev-gbl-02` | ✅ Good | ❌ None | Missing all tags |

---

## 8. Raw Data Notes

- **Deployment tooling**: The environment was deployed partially via `azd` (Azure Developer CLI) — evident from the `azd-service-name` tag on the Container App, the `azd-deploy-*` image tag in ACR, and the AZD-generated random suffix on `law-ai-dev-sdc-02-uzbv7zkmlm562`.
- **Two Log Analytics workspaces**: One created by `azd` (`law-ai-dev-sdc-02-uzbv7zkmlm562`) for Container Apps, and one created manually (`log-ai-dev-sdc-02`) linked to Application Insights — these overlap and create operational complexity.
- **Container App scales to zero**: `minReplicas=0` means the MCP server can have cold starts. No scale rules are defined, so it relies only on the default (HTTP request-based) scaling.
- **AI Search on Free tier**: Free tier is not suitable for production workloads — it has limitations (1 index max shared, no SLA, no private endpoints, no managed identity support).
- **Orca Security**: Cross-subscription Orca Security scanning is active (`DSPM Scanner Access` + `Side-Scanner` roles). This is an external security tool with read access.
- **No IaC artifacts in resource group**: The infrastructure appears to have been deployed via `azd` CLI interactively, with no Bicep or Terraform files tracked alongside the resources.
- **Container App revision suffix**: The latest revision is `ca-ai-dev-sdc-02--azd-1771930291`, last deployed 2026-02-24.
