# WAF/CAF Assessment — rg-dev-ai-sdc-02

## Assessment Summary

| Field | Value |
|-------|-------|
| **Environment** | DEV-PWR / `rg-dev-ai-sdc-02` |
| **Assessment Date** | 2026-03-15 |
| **Assessed By** | GitHub Copilot Reviewer Agent |
| **Framework References** | Azure Well-Architected Framework, Cloud Adoption Framework |
| **WAF Docs** | [learn.microsoft.com/azure/well-architected](https://learn.microsoft.com/azure/well-architected/) |
| **CAF Docs** | [learn.microsoft.com/azure/cloud-adoption-framework](https://learn.microsoft.com/azure/cloud-adoption-framework/) |

### Overall Health Score: **32 / 100** ⚠️ Needs Significant Improvement

This is a **development-stage AI workload** (MCP server with Azure AI Foundry, AI Search, and Bing Grounding) deployed partially via `azd` CLI. The environment demonstrates a "get it working" approach appropriate for early prototyping, but has significant gaps that must be addressed before any production promotion. The most acute risks are the absence of Key Vault, service principal credentials stored in plain text, no network isolation, an AI Search tier incapable of production use, and a complete absence of tags and alert rules.

| Pillar | Rating | Score |
|--------|--------|-------|
| Reliability | ❌ Non-Compliant | 20/100 |
| Security | ❌ Non-Compliant | 18/100 |
| Cost Optimization | ⚠️ Partial | 45/100 |
| Operational Excellence | ⚠️ Partial | 40/100 |
| Performance Efficiency | ⚠️ Partial | 42/100 |

---

## WAF Compliance Matrix

| Pillar | Rating | Key Findings |
|--------|--------|--------------|
| **Reliability** | ❌ Non-Compliant | No zone redundancy; scales to zero (cold starts); no health probes; no SLA on Free Search tier; no multi-region failover |
| **Security** | ❌ Non-Compliant | No Key Vault; client secret in plain text; no VNet/NSG/private endpoints; ACR admin user enabled; AI Services allow all traffic; no TLS minimum set; no Defender for AI |
| **Cost Optimization** | ⚠️ Partial | AI Search Free tier is non-billable but non-SLA; ACR Basic is low-cost; Consumption Container Apps is appropriate; duplicate Log Analytics workspaces wasteful |
| **Operational Excellence** | ⚠️ Partial | No IaC tracking; no alert rules; no diagnostic settings on AI Services/Search/ACR; two fragmented workspaces; zero tags; only azd-deployed partially |
| **Performance Efficiency** | ⚠️ Partial | Container App Consumption tier is appropriate; no scale rules defined; AI Search Free tier limits throughput; no caching layer; cold starts from minReplicas=0 |

---

## Detailed Pillar Analysis

### Pillar 1 — Reliability ❌ Non-Compliant

**Reference**: [Architecture best practices for Azure Container Apps — Reliability](https://learn.microsoft.com/azure/well-architected/service-guides/azure-container-apps#reliability) | [Reliability in Azure Container Apps](https://learn.microsoft.com/azure/reliability/reliability-container-apps)

#### Zone Redundancy
- **Finding**: `cae-ai-dev-sdc-02` has `zoneRedundant: false`. The Container Apps Environment is deployed on Consumption-only profile with no VNet, which means zone redundancy **cannot** be enabled on this environment. Zone redundancy requires a VNet-integrated environment with at least a `/23` subnet.
- **Impact**: A single availability zone failure would cause a complete service outage.
- **Remediation**: Create a new zone-redundant Container Apps Environment with VNet integration (dedicated subnet `/23` or larger), then redeploy the Container App. Note: zone redundancy cannot be enabled on an existing environment.
- **Ref**: [`reliability-container-apps#resilience-to-availability-zone-failures`](https://learn.microsoft.com/azure/reliability/reliability-container-apps#resilience-to-availability-zone-failures)

#### Minimum Replicas / Cold Starts
- **Finding**: `minReplicas=0` — the MCP server scales to zero. For a server-type workload (MCP), cold starts directly affect client usability.
- **Impact**: First-request latency can be 10–30 seconds on cold start. No SLA is provided when running at zero replicas.
- **Remediation**: Set `minReplicas=1` (or 2 for zone-fault tolerance) to eliminate cold starts. For zone redundancy, Microsoft recommends a minimum of 2+ replicas.

#### Health Probes
- **Finding**: No startup, liveness, or readiness probes configured on `ca-ai-dev-sdc-02` (`probes: []`).
- **Impact**: The platform cannot detect a hung or slow-start container, leading to unhealthy replicas receiving traffic.
- **Remediation**: Add at minimum a liveness probe (HTTP GET on `/health` or equivalent) and a readiness probe. Configure startup probe if the Python MCP server has a slow initialization path.
- **Ref**: [Architecture best practices — Configure health probes](https://learn.microsoft.com/azure/well-architected/service-guides/azure-container-apps#reliability)

#### Scale Rules
- **Finding**: No KEDA scale rules are defined. The Container App relies on default HTTP-scaling only.
- **Impact**: No controlled autoscaling under load; no predictable capacity behavior.
- **Remediation**: Define explicit HTTP concurrency-based scale rules. Example: scale out when concurrent requests > 10.

#### Backup & Restore
- **Finding**: No stateful resources requiring backup are present (Container Apps is stateless, AI Services and AI Search are managed PaaS). No data persistence layer (no storage accounts, no databases discovered).
- **Status**: N/A for this workload profile — no backup required at this time.

#### SLA Composition
| Resource | SLA |
|----------|-----|
| Azure Container Apps (Consumption) | 99.95% (when min replicas ≥ 1) |
| Azure AI Services (S0) | 99.9% |
| Azure AI Search (Free) | **No SLA** |
| Azure Container Registry (Basic) | 99.9% |
| **Composite (current)** | **No SLA** — dominated by Free Search tier |

---

### Pillar 2 — Security ❌ Non-Compliant

**Reference**: [Architecture best practices for Azure Container Apps — Security](https://learn.microsoft.com/azure/well-architected/service-guides/azure-container-apps#security) | [Secure Azure PaaS for AI](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/platform/security) | [AI Security benchmark](https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security)

#### Network Isolation
- **Finding**: Zero network isolation. No VNet, no NSGs, no private endpoints. The Container Apps Environment `vnetConfiguration: null`.
- **Impact**: All Azure services are reachable from the public internet. Any compromised or misconfigured resource is directly exposed.
- **WAF Requirement**: "Deploy private container apps environments and use internal ingress mode for isolation from the public internet. Control egress traffic to prevent data exfiltration."
- **Remediation**: Inject the Container Apps Environment into a VNet. For internal dependencies (ACR, AI Services, AI Search), configure private endpoints and disable public network access. Use UDR to route outbound traffic through Azure Firewall.
- **Ref**: [Security overview in Azure Container Apps — Network security](https://learn.microsoft.com/azure/container-apps/security#network-security)

#### Secrets Management — No Key Vault
- **Finding**: No Azure Key Vault exists in the resource group. Five secrets including `azure-client-secret` and `registry-password` are stored directly as Container App secrets.
- **Impact**: No secret rotation, no expiry enforcement, no centralized audit, no RBAC on secrets. Secrets accessible to any principal with Contributor access to the Container App.
- **WAF Requirement**: "Use managed identities where supported and store all other secrets in Key Vault."
- **Remediation**: Deploy Azure Key Vault. Migrate `azure-client-secret` and `registry-password` to Key Vault secrets. Configure the Container App to pull secrets from Key Vault via managed identity (requires enabling managed identity first).

#### Managed Identity — Container App
- **Finding**: `ca-ai-dev-sdc-02` has `identity.type: None`. All Azure service authentication uses a service principal client secret.
- **Impact**: Credential exposure risk; no automatic token rotation; violates WAF "use managed identities with Microsoft Entra ID for secure, credential-free access to Azure resources."
- **Remediation**: Enable System-Assigned Managed Identity on the Container App. Grant appropriate roles (e.g., `Cognitive Services User` on AI Services, `AcrPull` on the ACR). Remove `azure-client-id`, `azure-client-secret` secrets. Replace registry admin-user auth with managed identity ACR pull.
- **Ref**: [IM-3: Manage application identities securely and automatically](https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-identity-management#im-3)

#### ACR Admin User
- **Finding**: `adminUserEnabled: true` on `craiddevsdc02`. The admin password is stored as `registry-password` in the Container App.
- **Impact**: Shared static credentials; if leaked, full push/pull access to the entire registry. No per-identity audit trail.
- **Remediation**: Disable admin user. Grant `AcrPull` role to the Container App's managed identity. Remove `registry-password` secret.

#### AI Services — Public Access, Local Auth Enabled
- **Finding**: `publicNetworkAccess: Enabled`, `networkAcls.defaultAction: Allow`, `disableLocalAuth: false`.
- **Impact**: AI Services endpoint accessible from any IP, API keys functional (any holder of a key can make calls).
- **Remediation**: Set `networkAcls.defaultAction: Deny` with an allowlist of known IPs/VNet rules, or use private endpoint. Set `disableLocalAuth: true` to enforce Entra ID-only authentication against the managed identity.

#### AI Search — API Keys Only
- **Finding**: `authOptions.apiKeyOnly = {}`, `disableLocalAuth: false`. No managed identity, no RBAC-based access.
- **Impact**: API keys are static bearer tokens. If leaked, full query/manage access to the search service.
- **Remediation**: Switch to RBAC-based access (`authOptions: { aadOrApiKey: {} }` as intermediate step, then disable local auth). Add network restrictions or private endpoint (requires upgrading from Free tier).

#### TLS Minimum Version
- **Finding**: `minTlsVersion: null` on AI Services. No explicit TLS version enforcement found.
- **Impact**: Potential for downgrade attacks if older TLS versions are not blocked at the platform level.
- **Remediation**: Set `minTlsVersion: TLS1_2` on AI Services. Azure Container Apps enforces TLS 1.2+ on ingress by default (verified by `allowInsecure: false`).

#### Microsoft Defender
- **Finding**: No Microsoft Defender for Containers or Defender for AI enablement found in this resource group.
- **Impact**: No container image scanning, no runtime threat detection, no AI-specific threat protection.
- **Remediation**: Enable Microsoft Defender for Containers (scans ACR images). Evaluate Microsoft Defender for Cloud at subscription level for broader coverage.
- **Ref**: [Secure Azure PaaS for AI](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/platform/security)

#### mTLS / Peer Traffic Encryption
- **Finding**: mTLS disabled (`peerAuthentication.mtls.enabled: false`), peer traffic encryption disabled.
- **Impact**: East-west traffic between Container Apps in the same environment is not encrypted.
- **Remediation**: Enable mTLS for service-to-service communication. Enable peer traffic encryption.
- **Ref**: [Use mTLS](https://learn.microsoft.com/azure/container-apps/mtls)

---

### Pillar 3 — Cost Optimization ⚠️ Partial

**Reference**: [Azure Well-Architected Framework — Cost Optimization](https://learn.microsoft.com/azure/well-architected/cost-optimization/)

#### What is Working Well
- ✅ **Container Apps Consumption plan** — pay-per-use billing, scales to zero (currently by design). Appropriate for a development/prototype MCP server.
- ✅ **ACR Basic SKU** — lowest-cost tier, appropriate for a single development registry.
- ✅ **AI Services S0** — standard billing, appropriate for development.

#### Gaps

**AI Search Free Tier**
- **Finding**: `srch-ai-dev-sdc-02` is on Free SKU (`sku.name: free`).
- **Impact**: Free tier shares infrastructure, provides no SLA, is limited to 3 indexes and 50 MB storage. Cannot be used for production workloads. Cannot be upgraded in-place — requires a new service.
- **Remediation**: Deploy a new AI Search service at Basic or Standard tier when moving toward production. Delete the Free tier instance to avoid index fragmentation.
- **Cost Estimate**: Basic tier ~$73/month (1 replica, 1 partition, Sweden Central).

**Duplicate Log Analytics Workspaces**
- **Finding**: Two Log Analytics workspaces (`law-ai-dev-sdc-02-uzbv7zkmlm562` and `log-ai-dev-sdc-02`) both at PerGB2018 billing.
- **Impact**: Duplicated ingestion costs; fragmented observability; operational confusion.
- **Remediation**: Consolidate into a single workspace. Reconfigure the Container Apps Environment's `appLogsConfiguration` to point to `log-ai-dev-sdc-02`, which is already linked to Application Insights (creating a unified workspace-based App Insights setup). Delete the AZD-generated workspace.

**Reserved/Committed Use**
- **Finding**: No reserved capacity or committed use discounts in place.
- **Potential**: If the AI Services account will run continuously with predictable usage, a Provisioned Throughput Unit (PTU) commitment may reduce costs.

---

### Pillar 4 — Operational Excellence ⚠️ Partial

**Reference**: [Azure Well-Architected Framework — Operational Excellence](https://learn.microsoft.com/azure/well-architected/operational-excellence/)

#### Infrastructure as Code
- **Finding**: No Bicep, Terraform, or ARM template files tracked for this resource group. Deployment via `azd` CLI appears interactive/ad-hoc.
- **Impact**: No repeatable deployments; no drift detection; no peer review of infrastructure changes; no audit trail beyond resource change history.
- **Remediation**: Export `azd` infrastructure as Bicep templates. Commit to source control. Add PR-gated pipeline for infrastructure changes. Reference CAF approach of treating infrastructure as software.

#### Tagging — Complete Absence
- **Finding**: 10 out of 11 resources have zero CAF-required tags. Only `ca-ai-dev-sdc-02` has a single `azd-service-name` tag.
- **Impact**: No cost attribution, no filtering by environment/workload/owner, no policy enforcement.
- **Required Tags** (per CAF): `environment`, `workload`, `owner`, `costCenter`.
- **Remediation**: Apply tags via `az tag update` or IaC. Apply Azure Policy (`Require a tag on resources`) to enforce going forward. 
- **Ref**: [CAF Tagging strategy](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging)

#### Alert Rules
- **Finding**: Zero metric alert rules. Zero activity log alert rules. Only the auto-generated `Application Insights Smart Detection` action group exists.
- **Impact**: No proactive notification for failures, high error rates, scaling events, or security events.
- **Remediation**: Define at minimum:
  - Container App: alert on HTTP 5xx error rate > 1%
  - Container App: alert on replica count = 0 (unexpected scale-down)
  - AI Services: alert on throttled requests > threshold
  - AI Search: alert on query latency P99 > SLO
  - Action group: configure email/Teams notification target

#### Diagnostic Settings
- **Finding**: No diagnostic settings on `res-ai-dev-sdc-02`, `srch-ai-dev-sdc-02`, or `craiddevsdc02`.
- **Impact**: No request logs, audit logs, or metrics sent to Log Analytics for these resources. Security and usage tracing is blind.
- **Remediation**: Configure diagnostic settings on each resource, sending logs to `log-ai-dev-sdc-02`:
  - AI Services: `AuditEvent`, `RequestResponse` categories
  - AI Search: `OperationLogs` category
  - ACR: `ContainerRegistryLoginEvents`, `ContainerRegistryRepositoryEvents` categories

#### Application Insights Integration
- **Finding**: `appi-ai-dev-sdc-02` exists and is linked to `log-ai-dev-sdc-02`, but the Container App has no `APPLICATIONINSIGHTS_CONNECTION_STRING` environment variable configured.
- **Impact**: No APM telemetry (requests, dependencies, traces, exceptions) from the Python MCP server.
- **Remediation**: Pass the App Insights connection string to the Container App as an environment variable. Instrument the Python application with `opencensus-ext-azure` or `azure-monitor-opentelemetry`.

#### CI/CD Pipeline
- **Finding**: No evidence of a CI/CD pipeline. Deployments are via `azd` CLI manually.
- **Remediation**: Implement a GitHub Actions or Azure DevOps pipeline using `azd pipeline config`. Add container image scanning before push for supply chain security.

---

### Pillar 5 — Performance Efficiency ⚠️ Partial

**Reference**: [Azure Well-Architected Framework — Performance Efficiency](https://learn.microsoft.com/azure/well-architected/performance-efficiency/)

#### Container App Resource Sizing
- **Finding**: `cpu: 0.5`, `memory: 1Gi`. Appropriate for a lightweight Python MCP server in development.
- **Status**: ✅ Reasonable for current workload. Monitor actual usage with Application Insights before scaling up or down.

#### Scale Rules — Absent
- **Finding**: No KEDA scale rules. Default behavior scales on HTTP requests/connections.
- **Impact**: No fine-tuned scaling behavior (e.g., target concurrency, memory-based). Default HTTP scaling may over- or under-provision.
- **Remediation**: Define explicit HTTP scale rules: `--scale-rule-name http-scale --scale-rule-type http --scale-rule-http-concurrency 10`.

#### Cold Start Performance
- **Finding**: `minReplicas=0` with a Python container app. Python containers have non-trivial startup times.
- **Impact**: First user after an idle period experiences a 10–30+ second delay. MCP protocol clients may timeout.
- **Remediation**: Set `minReplicas=1`. Consider using a dedicated workload profile (via Consumption + Dedicated) to pre-warm containers.

#### AI Search Tier — Performance Bottleneck
- **Finding**: Free tier has shared, throttled infrastructure. Not suitable for any sustained query load.
- **Impact**: Query latency will be inconsistent. No throughput guarantees.
- **Remediation**: Upgrade to Basic or Standard tier for predictable performance.

#### Caching
- **Finding**: No Azure Cache for Redis or CDN configured.
- **Assessment**: For an MCP server routing requests to AI Services and Search, response caching could significantly reduce latency and cost. Evaluate APIM with semantic caching if AI query patterns are repetitive.
- **Ref**: [Azure API Management as AI Gateway](https://learn.microsoft.com/azure/api-management/) — semantic caching for AI responses.

#### Regional Placement
- **Finding**: All resources are in Sweden Central. Appropriate for European workloads. AI Services `res-ai-dev-sdc-02` (S0) is co-located in the same region.
- **Status**: ✅ Compliant — no latency concerns from regional misplacement.

---

## CAF Compliance Report

### Naming Convention Audit

CAF naming pattern reference: `<resource-prefix>-<workload>-<environment>-<region>[-<instance>]`

| Resource | Actual Name | CAF Pattern | Verdict | Issue |
|----------|------------|------------|---------|-------|
| Resource Group | `rg-dev-ai-sdc-02` | `rg-<workload>-<env>-<region>` | ⚠️ Partial | Environment (`dev`) is placed before workload (`ai`); CAF standard is workload-first: `rg-ai-dev-sdc-02` |
| Container App | `ca-ai-dev-sdc-02` | `ca-<workload>-<env>-<region>` | ✅ Good | Follows pattern well |
| Container Apps Env | `cae-ai-dev-sdc-02` | `cae-<workload>-<env>-<region>` | ✅ Good | Non-standard prefix `cae`, but consistent and descriptive |
| AI Services | `res-ai-dev-sdc-02` | More typically `cog-<workload>-<env>-<region>` | ⚠️ Partial | Prefix `res` is generic; CAF recommends `cog` for Cognitive/AI Services |
| AI Foundry Project | `proj-ai-dev-sdc-02` | No formal CAF prefix for AI Projects | ✅ Good | Reasonable and consistent |
| AI Search | `srch-ai-dev-sdc-02` | `srch-<workload>-<env>-<region>` | ✅ Good | Follows CAF exactly |
| Container Registry | `craiddevsdc02` | `cr<workload><env><region>` | ✅ Good | ACR cannot contain hyphens — concatenation is forced by platform constraint |
| Log Analytics (AZD) | `law-ai-dev-sdc-02-uzbv7zkmlm562` | `log-<workload>-<env>-<region>` | ❌ Non-Compliant | Wrong prefix (`law` vs `log`); AZD-appended random suffix deviates from CAF |
| Log Analytics (manual) | `log-ai-dev-sdc-02` | `log-<workload>-<env>-<region>` | ✅ Good | Correct prefix |
| Application Insights | `appi-ai-dev-sdc-02` | `appi-<workload>-<env>-<region>` | ✅ Good | Follows CAF exactly |
| Bing Grounding | `bng-ai-dev-gbl-02` | No formal CAF prefix | ✅ Good | Consistent with environment patterns; `gbl` for global region is appropriate |

**Naming Score: 7/11 ✅ — 2 ⚠️ Partial — 1 ❌**

### Tagging Audit

| Resource | `environment` | `workload` | `owner` | `costCenter` | Score |
|----------|:---:|:---:|:---:|:---:|:---:|
| `rg-dev-ai-sdc-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `ca-ai-dev-sdc-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `cae-ai-dev-sdc-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `res-ai-dev-sdc-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `res-ai-dev-sdc-02/proj-ai-dev-sdc-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `srch-ai-dev-sdc-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `craiddevsdc02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `law-ai-dev-sdc-02-uzbv7zkmlm562` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `log-ai-dev-sdc-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `appi-ai-dev-sdc-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |
| `bng-ai-dev-gbl-02` | ❌ | ❌ | ❌ | ❌ | 0/4 |

**Tagging Score: 0/44 ❌ — Complete absence of required CAF tags**

### Resource Organization Assessment

| Criterion | Status | Notes |
|-----------|--------|-------|
| Workload isolation in dedicated RG | ✅ | All AI resources in single `rg-dev-ai-sdc-02` |
| Logical grouping by function | ✅ | AI Services, compute, monitoring co-located |
| Multiple RGs for layered security | ❌ | Networking (if added) should be in a separate RG |
| Subscription alignment with CAF | ✅ | `DEV-PWR` subscription is environment-scoped |
| Management group hierarchy | N/A | Not assessed (subscription level) |

---

## Security Findings — Prioritized

### P1 — Critical

| # | Finding | Affected Resource(s) | Impact | Remediation |
|---|---------|---------------------|--------|-------------|
| P1-01 | **Client secret stored in Container App secrets — no Key Vault** | `ca-ai-dev-sdc-02` | Credential exposure; no rotation enforcement; accessible to all Contributor+ principals | Deploy Azure Key Vault; migrate `azure-client-secret` to KV; use managed identity |
| P1-02 | **No Managed Identity on Container App — service principal auth** | `ca-ai-dev-sdc-02` | Standing credential; if rotated externally, app breaks; violates WAF identity principles | Enable System-Assigned MI; assign `Cognitive Services User` + `AcrPull` roles; remove SP secrets |
| P1-03 | **ACR Admin User enabled and actively used for image pull** | `craiddevsdc02` | Shared static password; no audit trail per deployment; full push/pull access if leaked | Disable admin user; use managed identity `AcrPull` role assignment |

---

### P2 — High

| # | Finding | Affected Resource(s) | Impact | Remediation |
|---|---------|---------------------|--------|-------------|
| P2-01 | **No network isolation — no VNet, no NSGs, no private endpoints** | All resources | All PaaS services reachable from internet; no data exfiltration controls | VNet-inject Container Apps Environment; add private endpoints for ACR, AI Services, AI Search |
| P2-02 | **AI Services API keys enabled (local auth not disabled)** | `res-ai-dev-sdc-02` | API keys are long-lived tokens with no IP restriction; any key holder has full API access | Set `disableLocalAuth: true`; enforce Entra ID RBAC; restrict network ACLs |
| P2-03 | **AI Search API keys only — no Entra ID auth** | `srch-ai-dev-sdc-02` | Static API keys; no RBAC enforcement; no audit at identity level | Enable RBAC on Search (`authOptions: aadOrApiKey`); disable local auth; upgrade from Free tier |
| P2-04 | **No diagnostic settings on AI Services, AI Search, ACR** | `res-ai-dev-sdc-02`, `srch-ai-dev-sdc-02`, `craiddevsdc02` | No audit trail of requests; security investigations cannot trace API usage | Configure diagnostic settings → `log-ai-dev-sdc-02` workspace |
| P2-05 | **mTLS disabled in Container Apps Environment** | `cae-ai-dev-sdc-02` | East-west traffic between apps in the same environment is unencrypted | Enable `peerAuthentication.mtls.enabled: true` and `peerTrafficEncryption.enabled: true` |

---

### P3 — Medium

| # | Finding | Affected Resource(s) | Impact | Remediation |
|---|---------|---------------------|--------|-------------|
| P3-01 | **Zero CAF tags on all resources** | All 11 resources | No cost attribution; no owner accountability; Azure Policy cannot filter by workload | Apply 4 required tags; enforce via Azure Policy `Require a tag on resources` |
| P3-02 | **Container App minReplicas=0 with no scale rules** | `ca-ai-dev-sdc-02` | Cold starts impact user experience; no auto-scale for load | Set `minReplicas=1`; define HTTP concurrency scale rule |
| P3-03 | **No alert rules defined** | Resource group | Silent failures; no proactive incident response | Define metric alerts for HTTP errors, replica count, API throttling |
| P3-04 | **No health probes on Container App** | `ca-ai-dev-sdc-02` | Unhealthy replicas receive traffic; no automatic self-healing | Add liveness and readiness probes |
| P3-05 | **AI Search on Free tier — no SLA, no production capability** | `srch-ai-dev-sdc-02` | Cannot be used for production; limits indexes to 3; shared infrastructure | Upgrade to Basic ($73/mo) or Standard ($253/mo) when productionizing |
| P3-06 | **Duplicate Log Analytics workspaces** | `law-ai-dev-sdc-02-uzbv7zkmlm562`, `log-ai-dev-sdc-02` | Fragmented observability; duplicate ingestion costs; operational confusion | Consolidate to `log-ai-dev-sdc-02`; delete AZD-generated workspace |
| P3-07 | **CAF naming violations** | `law-ai-dev-sdc-02-uzbv7zkmlm562`, `res-ai-dev-sdc-02` | Inconsistency; harder to apply automation/policy by name pattern | Rename resources where feasible during next deployment cycle |
| P3-08 | **No CI/CD pipeline — manual `azd` deployments** | All resources | No gated deployments; no drift detection; no peer review of changes | Implement GitHub Actions with `azd pipeline config`; add container scanning |

---

### P4 — Low

| # | Finding | Affected Resource(s) | Impact | Remediation |
|---|---------|---------------------|--------|-------------|
| P4-01 | **No Application Insights SDK in Python app** | `ca-ai-dev-sdc-02` | No APM telemetry; requests, exceptions, dependencies not tracked | Add `APPLICATIONINSIGHTS_CONNECTION_STRING` env var; instrument with `azure-monitor-opentelemetry` |
| P4-02 | **No Microsoft Defender for Containers** | `craiddevsdc02` | No image vulnerability scanning; no runtime threat detection | Enable Defender for Containers at subscription level |
| P4-03 | **No explicit TLS minimum version on AI Services** | `res-ai-dev-sdc-02` | Potential for TLS downgrade if not enforced at network layer | Set `minTlsVersion: TLS1_2` |
| P4-04 | **Bing Grounding on G1 SKU — review necessity** | `bng-ai-dev-gbl-02` | Grounding charges accumulate per query; ensure Bing usage is intentional and bounded | Review Bing API call volume; add usage alerts; consider budget cap |
| P4-05 | **No budget/cost alerts at resource group level** | Resource group | Unexpected spend goes unnoticed | Create Azure Budget for the resource group with 80%/100% threshold alerts |

---

## Top 10 Recommendations

| Priority | Recommendation | Effort | Benefit |
|----------|---------------|--------|---------|
| 1 | **Deploy Azure Key Vault and migrate all secrets** — Remove client secret and ACR password from Container App config; store in KV; use managed identity for access | Medium | Eliminates P1-01, P1-03, unblocks identity remediation |
| 2 | **Enable Managed Identity on Container App** — System-Assigned MI + `AcrPull` + `Cognitive Services User` role assignments; disable SP credential use | Low | Eliminates P1-02, partially addresses P2-02; no cost |
| 3 | **Disable ACR Admin User** — Enforce MI-based image pull; rotate/revoke admin credentials | Low | Eliminates P1-03; no cost |
| 4 | **Add network isolation via VNet injection** — Create a VNet with `/23` subnet for Container Apps; inject `cae-ai-dev-sdc-02` (requires new environment); add private endpoints for ACR and AI Services | High | Addresses P2-01; enables zone redundancy as a follow-on |
| 5 | **Configure diagnostic settings on AI Services, Search, ACR** — Route audit/request logs to `log-ai-dev-sdc-02` | Low | Addresses P2-04; enables security investigation capability; minimal cost |
| 6 | **Apply CAF tags to all resources** — Apply `environment=dev`, `workload=ai-mcp-server`, `owner`, `costCenter` via CLI or IaC | Low | Addresses P3-01; prerequisite for cost allocation and policy enforcement |
| 7 | **Define alert rules** — HTTP 5xx rate, replica count, AI throttling, budget alerts | Low | Addresses P3-03; enables proactive operations |
| 8 | **Set `minReplicas=1` and define scale rules** — Eliminate cold starts for MCP server; add explicit HTTP concurrency rule | Low | Addresses P3-02; improves reliability and performance |
| 9 | **Consolidate Log Analytics workspaces** — Migrate Container Apps logs to `log-ai-dev-sdc-02`; delete AZD-generated workspace | Low | Addresses P3-06; unifies observability; reduces cost |
| 10 | **Upgrade AI Search from Free to Basic tier** — Required before any production readiness milestone; new service must be created (cannot upgrade in-place) | Low | Addresses P3-05; provides SLA, private endpoint support, managed identity support |

---

## References

| Document | URL |
|----------|-----|
| Azure Well-Architected Framework | https://learn.microsoft.com/azure/well-architected/ |
| WAF — Container Apps best practices | https://learn.microsoft.com/azure/well-architected/service-guides/azure-container-apps |
| WAF — Reliability in Container Apps | https://learn.microsoft.com/azure/reliability/reliability-container-apps |
| WAF — Security in Container Apps | https://learn.microsoft.com/azure/container-apps/security |
| WAF — Zone redundancy how-to | https://learn.microsoft.com/azure/container-apps/how-to-zone-redundancy |
| CAF — Secure Azure PaaS for AI | https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/ai/platform/security |
| CAF — Naming conventions | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming |
| CAF — Tagging strategy | https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging |
| Microsoft Cloud Security Benchmark — AI Security | https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-artificial-intelligence-security |
| Microsoft Cloud Security Benchmark — Identity Management | https://learn.microsoft.com/security/benchmark/azure/mcsb-v2-identity-management#im-3 |
