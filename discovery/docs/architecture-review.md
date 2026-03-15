# Architecture Review — Migration Target State
### WAF/CAF Assessment of Proposed Production Architecture | rg-dev-ai-sdc-02

| Field | Value |
|-------|-------|
| **Review Date** | 2026-03-15 |
| **Reviewed By** | GitHub Copilot Reviewer Agent |
| **Architecture Source** | `discovery/docs/migration-plan.md` — Section 3 (Target-State Architecture) |
| **Framework References** | Azure Well-Architected Framework · Cloud Adoption Framework |
| **Scope** | Target state only — not the migration migration execution steps |

---

## 1. Review Summary

The proposed target architecture is a **substantial improvement** over the current state (32/100 → projected ~79/100) and correctly identifies and remediates the most critical gaps: managed identity, Key Vault, private endpoints, zone redundancy, and unified monitoring. The directional decisions are sound and aligned with WAF/CAF principles.

However, this review identifies **two P1 issues** and several P2/P3 findings that must be resolved before the target design can be considered production-ready:

1. **P1 — Azure does not support renaming resource groups.** The migration plan describes "Rename + apply CAF tags" for the resource group. This operation does not exist in Azure. Achieving the CAF-correct name `rg-ai-dev-sdc-02` requires creating a new resource group and moving or recreating all resources — a significantly more complex operation than the plan acknowledges.
2. **P1 — No NSGs on VNet subnets.** The target VNet has two subnets (`snet-app-dev-sdc-02` and `snet-pe-dev-sdc-02`) with no Network Security Groups. This is a security gap — NSGs are required for defense-in-depth even within a private VNet.

**Target Health Score: 79 / 100** (projected, pending gap remediation)

| Pillar | Current | Target (Projected) | Delta |
|--------|:------:|:------------------:|:-----:|
| Reliability | ❌ 20/100 | ✅ 85/100 | +65 |
| Security | ❌ 18/100 | ⚠️ 78/100 | +60 |
| Cost Optimization | ⚠️ 45/100 | ⚠️ 75/100 | +30 |
| Operational Excellence | ⚠️ 40/100 | ⚠️ 80/100 | +40 |
| Performance Efficiency | ⚠️ 42/100 | ⚠️ 76/100 | +34 |
| **Overall** | **32/100** | **~79/100** | **+47** |

---

## 2. WAF Compliance Matrix — Target State

| Pillar | Rating | Key Findings |
|--------|--------|--------------|
| **Reliability** | ✅ Compliant | Zone-redundant CAE with VNet; min=2 replicas; health probes; scale rules; SLA 99.9% composite; one gap: AI Search Basic is single-replica |
| **Security** | ⚠️ Partial | Strong identity + private endpoint design; **no NSGs on subnets**; **no egress Firewall for Bing traffic**; App Insights still public ingestion |
| **Cost Optimization** | ⚠️ Partial | Good SKU choices; no App Insights sampling rate specified; APIM semantic caching deferred but not planned |
| **Operational Excellence** | ⚠️ Partial | CI/CD + IaC + unified monitoring achieved; no drift detection mechanism; no key rotation schedule; migration artifact names need cleanup |
| **Performance Efficiency** | ⚠️ Partial | Cold starts eliminated; scale rules added; no caching layer; container resource sizing not re-evaluated against measured load |

---

## 3. Detailed Pillar Review

### Pillar 1 — Reliability ✅ Compliant (85/100)

#### What the Target Gets Right
- ✅ **Zone-redundant Container Apps Environment** — VNet-injected with `/23` subnet correctly sized for zone redundancy. This is the most impactful reliability improvement.
- ✅ **`minReplicas=2`** — eliminates cold starts and ensures at least one replica survives a single AZ failure.
- ✅ **Health probes (liveness + readiness)** — unhealthy replicas will be detected and replaced automatically.
- ✅ **Explicit HTTP concurrency scale rules** — predictable autoscaling behavior under load.
- ✅ **SLA composition** — with AI Services S0 (99.9%), AI Search Basic (99.9%), ACR Basic (99.9%), and CA Consumption (99.95%), the composite SLA is approximately **99.75%** (~2.2 hours downtime/year). This is a significant improvement from "No SLA".
- ✅ **mTLS enabled** — peer-to-peer traffic encrypted; platform will restart unhealthy replicas.

#### Gaps

**AI Search Basic — Single Replica**
- **Finding**: AI Search Basic tier deploys with 1 replica by default. A single replica provides no redundancy within the service.
- **Impact**: An AI Search service disruption (maintenance, single-node failure) causes complete loss of search capability. The composite SLA is 99.9% but depends on single-instance availability.
- **Recommendation**: Add a second replica to the AI Search Basic service for better availability and balanced query throughput. Second replica doubles the service cost (~$146/month) but brings the service closer to genuine HA. Alternatively, accept single replica at Basic for dev and document as a known limitation.
- **Ref**: [Azure AI Search — Scale for availability](https://learn.microsoft.com/azure/search/search-reliability)

**No Multi-Region Failover**
- **Finding**: All resources are in Sweden Central with no cross-region replication or failover.
- **Assessment**: Appropriate for a development environment. Document explicitly that multi-region is a prerequisite for any production SLA > 99.9%. Include as a future backlog item.
- **Rating**: ✅ Acceptable for dev; flag for production promotion.

---

### Pillar 2 — Security ⚠️ Partial (78/100)

#### What the Target Gets Right
- ✅ **Private endpoints** for all 4 internal services (AI Services, AI Search, ACR, Key Vault).
- ✅ **Public access disabled** on AI Services, AI Search, and ACR in Phase 3.
- ✅ **Managed Identity** on Container App with least-privilege roles (`Cognitive Services User`, `AcrPull`, `Key Vault Secrets User`, `Search Index Data Reader`).
- ✅ **Key Vault** with RBAC access model, soft-delete, purge protection, and private endpoint.
- ✅ **Local auth disabled** on AI Services and AI Search — Entra ID-only authentication.
- ✅ **TLS 1.2 minimum** set on AI Services.
- ✅ **mTLS + peer traffic encryption** in Container Apps Environment.
- ✅ **Defender for Containers** enabled at subscription level.
- ✅ **ACR admin user disabled** — all pulls via managed identity.

#### Gaps

**P1-REVIEW-01 — No NSGs on VNet Subnets**
- **Finding**: The target architecture defines two subnets (`snet-app-dev-sdc-02` and `snet-pe-dev-sdc-02`) but no Network Security Groups are associated with them.
- **Impact**: No layer-4 traffic filtering within the VNet. If any resource is compromised, lateral movement between subnets is unrestricted. NSGs are a fundamental network control layer that all WAF guidance requires.
- **WAF Requirement**: "Use network security groups or Azure Firewall to control inter-subnetwork traffic." ([WAF Container Apps security](https://learn.microsoft.com/azure/well-architected/service-guides/azure-container-apps#security))
- **Recommendation**: Create and associate NSGs:
  - `nsg-app-dev-sdc-02` → associated with `snet-app-dev-sdc-02`: Allow inbound HTTPS from internet (via CAE ingress controller); deny all other inbound.
  - `nsg-pe-dev-sdc-02` → associated with `snet-pe-dev-sdc-02`: Allow inbound from `snet-app-dev-sdc-02` on service-specific ports only (443 for all); deny all other inbound; deny all outbound except to private link.
- **Effort**: Low — add to Phase 1 VNet deployment.
- **Ref**: [Network security groups — Azure Virtual Network](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)

**P2-REVIEW-01 — No Egress Firewall for Bing Grounding Traffic**
- **Finding**: The Container App makes outbound HTTPS calls to `api.bing.microsoft.com` (a global public endpoint). The plan acknowledges this but does not include Azure Firewall or UDR-based egress control.
- **Impact**: All outbound internet traffic from the Container App is unrestricted. A compromised container could exfiltrate data to any internet destination. Without a Firewall, the only control is the Bing API key.
- **Recommendation**: Either:
  - (a) Deploy Azure Firewall in a dedicated subnet; add UDR to `snet-app-dev-sdc-02` routing `0.0.0.0/0` to Firewall; allow-list only `api.bing.microsoft.com` and Azure service tags. **This adds ~$900/month for Standard Firewall** — may be disproportionate for dev.
  - (b) As a lower-cost alternative, implement egress control at the application layer: use Azure Container Apps' built-in environment-level egress IP (`135.116.0.47`) and configure Bing API IP allowlists, plus implement a circuit breaker in the Python code to limit Bing call scope.
  - (c) Accept the risk for dev; document Azure Firewall as a hard requirement before production.
- **Effort**: High (Firewall) / Low (application-layer controls).

**P2-REVIEW-02 — Application Insights Ingestion Not Fully Private**
- **Finding**: The migration plan mentions "private ingestion" for App Insights (`appi-ai-dev-sdc-02`) but no private endpoint for the Application Insights workspace is included in the target architecture diagram or resource map.
- **Impact**: Application telemetry (including request metadata, dependency traces, and custom events) is sent over the public internet to `dc.applicationinsights.azure.com`. This violates the "no public egress" principle of the target architecture.
- **Recommendation**: Deploy an Azure Monitor Private Link Scope (AMPLS) resource connecting `log-ai-dev-sdc-02` and `appi-ai-dev-sdc-02` to the VNet via a private endpoint. This is a single PE covering both resources.
- **Resource name suggestion**: `pep-mon-dev-sdc-02` in `snet-pe-dev-sdc-02`.
- **Cost**: +~$7.30/month (1 additional PE).
- **Ref**: [Use Azure Private Link to connect networks to Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/logs/private-link-security)

**P3-REVIEW-01 — Key Vault Diagnostic Settings Not Included**
- **Finding**: Diagnostic settings are configured for AI Services, ACR, and AI Search (Phase 0, task 0.7), but Key Vault is not listed.
- **Impact**: Key Vault access logs (who accessed which secret, when) are not captured. This is a critical audit trail for a secrets management service.
- **Recommendation**: Add `AuditEvent` diagnostic category on `kv-ai-dev-sdc-02` → `log-ai-dev-sdc-02` as part of Phase 0 task 0.7.

---

### Pillar 3 — Cost Optimization ⚠️ Partial (75/100)

#### What the Target Gets Right
- ✅ Container Apps Consumption plan retained — appropriate for this workload; pay-per-use.
- ✅ ACR Basic retained — correct choice; no geo-replication needed for dev.
- ✅ Duplicate Log Analytics eliminated — cost reduction.
- ✅ Cost optimization table in Section 8.4 covers the major levers.
- ✅ AI Search Basic at ~$73/month is the correct minimum productiontier for SLA + private endpoint.

#### Gaps

**P3-REVIEW-02 — App Insights Sampling Not Specified**
- **Finding**: The target notes "Sampling configured" but does not specify a sampling rate or strategy.
- **Impact**: At 100% sampling (the default), a high-throughput MCP server can generate significant App Insights data charges. For an AI workload routing many requests, this can exceed the Log Analytics cost itself.
- **Recommendation**: Configure adaptive sampling in the `azure-monitor-opentelemetry` SDK (the default) and set a maximum telemetry per-second limit. Alternatively set fixed-percentage sampling at 20–50% to cap costs, while retaining sufficient data for diagnostics.
- **Ref**: [Sampling in Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/sampling)

**P4-REVIEW-01 — APIM Semantic Caching Not Planned**
- **Finding**: The cost optimization table mentions APIM semantic caching but it is classified as "Phase 3 follow-on" without a concrete plan or timeline.
- **Impact**: For an MCP server processing repetitive AI completions queries, semantic caching could reduce AI API costs by 20–40%. At current AI Services pricing this could be significant at scale.
- **Recommendation**: Add APIM as a Phase 3 task rather than a future backlog item. A basic APIM Consumption tier ($0/month for first 1M calls) in front of the AI Services endpoint is low-cost and high-value.

---

### Pillar 4 — Operational Excellence ⚠️ Partial (80/100)

#### What the Target Gets Right
- ✅ CI/CD pipeline via GitHub Actions + azd.
- ✅ Bicep IaC exported and committed to source control.
- ✅ Unified Log Analytics workspace with diagnostic settings on all resources.
- ✅ Action Group + metric alert rules.
- ✅ Full CAF tagging on all resources.
- ✅ Resource locks on critical resources (KV, VNet, Log Analytics).
- ✅ Operations runbook as a Phase 3 deliverable.

#### Gaps

**P2-REVIEW-03 — Resource Group Cannot Be Renamed in Azure**
- **Finding**: The migration plan resource map states: `rg-dev-ai-sdc-02` → `rg-ai-dev-sdc-02`, action: "Rename + apply CAF tags." **Azure does not support renaming resource groups.** There is no `az group rename` command.
- **Impact**: The target CAF-compliant name `rg-ai-dev-sdc-02` cannot be achieved by renaming. To achieve it, resources must be moved to a new resource group, which requires:
  - Creating a new RG `rg-ai-dev-sdc-02`.
  - Moving resources via `az resource move` — but Container Apps Environments, Container Apps, and some cognitive services **cannot be moved between resource groups** and must be recreated.
  - This effectively makes Phase 2 (CAE recreation) the natural point to also deploy to a new RG.
- **Recommendation**: Update the migration plan to reflect the correct approach:
  1. In Phase 2, create new CAE and Container App in `rg-ai-dev-sdc-02` (new RG).
  2. In Phase 1, create VNet, KV, and private endpoints in `rg-ai-dev-sdc-02`.
  3. Move moveable resources (AI Services, ACR, Log Analytics, App Insights): `az resource move --destination-group rg-ai-dev-sdc-02 --ids <resource-ids>`. Verify each resource type supports move before attempting.
  4. Recreate non-moveable resources (CA, CAE) in the new RG.
  5. Delete `rg-dev-ai-sdc-02` at end of migration.
- **Alternative**: Accept the non-CAF RG name `rg-dev-ai-sdc-02` as a known deviation. Apply the 4 required tags. Document as a technical debt item.

**P3-REVIEW-03 — Migration Artifact Names Need a Cleanup Plan**
- **Finding**: Two target resources have migration-artifact suffixes:
  - `cae-ai-dev-sdc-02-new` — temporary name during CAE recreation. After old CAE is deleted (Phase 2.5), the new CAE should be renamed to `cae-ai-dev-sdc-02`. But CAE names cannot be changed after creation.
  - `srch-ai-dev-sdc-02-basic` — temporary name for the new AI Search service. After the Free tier is deleted (Phase 1.10), the final name should be `srch-ai-dev-sdc-02`. AI Search **can** be created with any name — use `srch-ai-dev-sdc-02` directly at creation.
- **Impact**: Resource names with `-new` and `-basic` suffixes are non-CAF compliant and create confusion in alerts, dashboards, and IaC.
- **Recommendation**:
  - Create the new AI Search service as `srch-ai-dev-sdc-02` from the start (run it in parallel with the Free tier using the distinct name only during the cutover window — not an issue since AI Search names are globally unique per subscription).
  - Accept that the new CAE will be named `cae-ai-dev-sdc-02-new` during migration, then plan for the domain name change when the old one is deleted. Document the final FQDN change and its impact on MCP clients.

**P3-REVIEW-04 — No Key Rotation Schedule for Bing API Key**
- **Finding**: The Bing Grounding API key will be stored in Key Vault, but no rotation schedule is defined.
- **Impact**: Long-lived API keys represent a persistent credential exposure risk if the Key Vault is ever compromised or the key is accessed by an unauthorized principal.
- **Recommendation**: Set a key expiry in Key Vault (90-day rotation). Configure Key Vault expiry alerts. Document the rotation procedure in the operations runbook. Add `Key Vault — Secret Expiry` alert to the Action Group.

**P3-REVIEW-05 — No Drift Detection in CI/CD Specification**
- **Finding**: Phase 3.8 says "commit IaC to source control" and "pipeline validates on PR" but does not specify a drift detection mechanism (e.g., scheduled `az deployment what-if` or `azd diff`).
- **Impact**: Manual ad-hoc changes (applied directly via portal or CLI) will cause drift between IaC and deployed state with no alert.
- **Recommendation**: Add a scheduled GitHub Actions workflow (daily or weekly) running `az deployment group what-if` against the deployed state. Alert on any detected drift via the Action Group.

**P4-REVIEW-02 — No Pre-Migration Performance Baseline**
- **Finding**: Performance baseline (Phase 3.6) is scheduled after migration. There is no baseline captured before Phase 0 begins.
- **Impact**: Without a pre-migration baseline, it is impossible to verify whether the migrated architecture performs better, worse, or the same. The acceptance criteria target "within acceptable bounds" with no defined reference.
- **Recommendation**: Add Phase 0 task: "Capture performance baseline — run representative load test against current environment; record P50/P95/P99 latency for MCP calls, AI completions, and search queries." Use these numbers as the acceptance threshold in Phase 3.6.

---

### Pillar 5 — Performance Efficiency ⚠️ Partial (76/100)

#### What the Target Gets Right
- ✅ Cold starts eliminated (`minReplicas=2`).
- ✅ Explicit KEDA HTTP concurrency scale rules.
- ✅ All resources co-located in Sweden Central — no cross-region latency.
- ✅ AI Search Basic appropriate for initial production query load.
- ✅ Container Apps Consumption appropriate for variable MCP traffic.

#### Gaps

**P3-REVIEW-06 — Container App Resource Sizing Not Re-evaluated**
- **Finding**: The target retains `cpu=0.5 vCPU / memory=1 GiB` from the current state. No performance analysis justifies this allocation for the target load (2 replicas receiving real traffic vs. previous scale-to-zero prototype).
- **Impact**: If the workload is CPU-bound (Python AI inference orchestration can be), under-provisioning will cause high latency under concurrent requests. Over-provisioning wastes cost.
- **Recommendation**: Combine with the pre-migration baseline (P4-REVIEW-02 above). Add a Phase 2 subtask: "Validate replica CPU/memory utilization after 24h of traffic; adjust if P95 CPU > 70%." Establish monitoring dashboards for CPU/memory metrics in App Insights.

**P3-REVIEW-07 — No Caching Layer in Target Architecture**
- **Finding**: No Azure Cache for Redis or APIM semantic caching is included in the target architecture. Section 8.4 lists APIM caching as a future optimization, not a planned deliverable.
- **Impact**: Every MCP request that maps to an identical AI completion or search query makes a full round-trip to AI Services/Search. For repetitive queries (common in AI agent scenarios), this inflates both latency and API cost.
- **Recommendation**: Evaluate APIM Consumption tier as an AI gateway layer in Phase 3. Even without full semantic caching, APIM adds rate limiting, request logging, and retry policies — all WAF-aligned. If query patterns are confirmed repetitive from App Insights telemetry, enable semantic caching.

**P4-REVIEW-03 — AI Search Basic Single Partition**
- **Finding**: AI Search Basic tier is deployed with 1 replica and 1 partition (default). Query throughput is capped at a single partition's capacity.
- **Impact**: For high-throughput search scenarios, a single partition can become a bottleneck. Basic tier supports up to 3 replicas and 1 partition.
- **Recommendation**: Add 1 additional replica to AI Search Basic (total: 2 replicas) for load-balanced query processing and improved availability. This doubles the monthly cost (~$146/month). Evaluate after the performance baseline is measured.

---

## 4. CAF Compliance Review — Target State

### 4.1 Naming Convention Audit

| Resource | Proposed Name | CAF Pattern | Verdict | Issue |
|----------|--------------|------------|---------|-------|
| Resource Group | `rg-ai-dev-sdc-02` | `rg-<workload>-<env>-<region>` | ✅ Correct | Workload-first order corrected from current state |
| VNet | `vnet-ai-dev-sdc-02` | `vnet-<workload>-<env>-<region>` | ✅ Correct | |
| Subnet (CAE) | `snet-app-dev-sdc-02` | `snet-<purpose>-<env>-<region>` | ✅ Correct | |
| Subnet (PE) | `snet-pe-dev-sdc-02` | `snet-<purpose>-<env>-<region>` | ✅ Correct | |
| Container App | `ca-ai-dev-sdc-02` | `ca-<workload>-<env>-<region>` | ✅ Correct | Unchanged; correct |
| Container Apps Env | `cae-ai-dev-sdc-02-new` | `cae-<workload>-<env>-<region>` | ⚠️ Partial | `-new` suffix is migration artifact; CAE names cannot be changed post-creation |
| AI Services | `res-ai-dev-sdc-02` | CAF recommends `cog-<workload>-<env>-<region>` | ⚠️ Partial | `res` prefix retained; renaming would require resource recreation |
| AI Foundry Project | `proj-ai-dev-sdc-02` | No formal CAF prefix | ✅ Good | Unchanged; no change needed |
| AI Search | `srch-ai-dev-sdc-02-basic` | `srch-<workload>-<env>-<region>` | ⚠️ Partial | `-basic` suffix is migration artifact; new service should be created as `srch-ai-dev-sdc-02` directly |
| Container Registry | `craiddevsdc02` | `cr<workload><env><region>` | ✅ Correct | Platform constraint (no hyphens); unchanged |
| Key Vault | `kv-ai-dev-sdc-02` | `kv-<workload>-<env>-<region>` | ✅ Correct | New resource; correct name |
| Log Analytics | `log-ai-dev-sdc-02` | `log-<workload>-<env>-<region>` | ✅ Correct | Unchanged; correct |
| App Insights | `appi-ai-dev-sdc-02` | `appi-<workload>-<env>-<region>` | ✅ Correct | Unchanged; correct |
| Private Endpoint (AI) | `pep-ai-dev-sdc-02` | `pep-<resource>-<env>-<region>` | ✅ Correct | |
| Private Endpoint (Search) | `pep-srch-dev-sdc-02` | `pep-<resource>-<env>-<region>` | ✅ Correct | |
| Private Endpoint (ACR) | `pep-acr-dev-sdc-02` | `pep-<resource>-<env>-<region>` | ✅ Correct | |
| Private Endpoint (KV) | `pep-kv-dev-sdc-02` | `pep-<resource>-<env>-<region>` | ✅ Correct | |
| Action Group | `ag-ai-dev-sdc-02` | No formal CAF prefix for action groups | ✅ Good | Consistent and descriptive |
| NSGs (missing) | `nsg-app-dev-sdc-02`, `nsg-pe-dev-sdc-02` | `nsg-<purpose>-<env>-<region>` | ❌ Missing | NSGs not in plan; should be added with CAF-compliant names |

**Naming Score: 14 Correct / 3 Partial / 1 Missing**

### 4.2 Tagging

The migration plan (Phase 0, task 0.1) applies all 4 required CAF tags to all 11 existing resources via `az tag update`. New resources created in Phases 1–3 must also be tagged at provisioning time in IaC.

**Recommendation**: Ensure all new Bicep resources include the tag block:

```bicep
tags: {
  environment: 'dev'
  workload: 'ai-mcp-server'
  owner: 'alberto.aguzzi@evides.nl'
  costCenter: '<billing-code>'
}
```

Add an Azure Policy `Require a tag on resources` to enforce `environment`, `workload`, `owner`, `costCenter` going forward.

### 4.3 Resource Group Strategy

The plan proposes correcting the resource group name from `rg-dev-ai-sdc-02` to `rg-ai-dev-sdc-02`. As noted in finding P2-REVIEW-03, this requires either accepting the current name or coordinating a full resource recreation/move. Regardless of which approach is taken, the logical grouping (all AI workload resources in one RG) is correct and consistent with CAF landing zone principles.

---

## 5. AVM / IaC Compliance

The migration plan specifies "Export azd infrastructure as Bicep" (Phase 3.8) but does not prescribe Azure Verified Modules. For new resources (VNet, private endpoints, Key Vault), using AVM modules is recommended.

### Recommended AVM Modules

| Resource | AVM Module | Notes |
|---------|-----------|-------|
| Key Vault | `br/public:avm/res/key-vault/vault:<version>` | Use latest pinned version |
| Virtual Network | `br/public:avm/res/network/virtual-network:<version>` | Subnets as params |
| Private Endpoint | `br/public:avm/res/network/private-endpoint:<version>` | One module per PE |
| Private DNS Zone | `br/public:avm/res/network/private-dns-zone:<version>` | One module per zone |
| NSG | `br/public:avm/res/network/network-security-group:<version>` | Required — missing from plan |
| Log Analytics | `br/public:avm/res/operational-insights/workspace:<version>` | For IaC-managed workspace |
| Container Registry | `br/public:avm/res/container-registry/registry:<version>` | Manage existing via IaC |

**Ref**: [Azure Verified Modules — Browse registry](https://azure.github.io/Azure-Verified-Modules/indexes/bicep/)

---

## 6. Security Findings — Prioritized

### P1 — Critical (Must Fix Before Implementation)

| # | Finding | Affected Task | Impact | Required Action |
|---|---------|--------------|--------|----------------|
| P1-REVIEW-01 | **No NSGs on VNet subnets** — no layer-4 traffic filtering; lateral movement unrestricted within VNet | Phase 1 | High | Add `nsg-app-dev-sdc-02` and `nsg-pe-dev-sdc-02` to Phase 1 VNet deployment |
| P1-REVIEW-02 | **Resource Group rename is not possible in Azure** — "Rename" action described in migration plan does not exist | Phase 0/All | Medium | Either accept current RG name as known deviation, or restructure Phases 1–2 to deploy new resources into a new `rg-ai-dev-sdc-02` and migrate/recreate |

### P2 — High

| # | Finding | Affected Task | Impact | Required Action |
|---|---------|--------------|--------|----------------|
| P2-REVIEW-01 | **No egress Firewall** — Container App outbound internet access to Bing is unrestricted | Phase 2 | Medium | Implement application-layer egress controls (circuit breaker, scoped Bing calls) at minimum; plan Azure Firewall for production |
| P2-REVIEW-02 | **App Insights ingestion not private** — telemetry sent over public internet despite VNet isolation goal | Phase 2 | Medium | Add Azure Monitor Private Link Scope (AMPLS) + PE to Phase 1 network plan |
| P2-REVIEW-03 | **RG rename operation is incorrect** — described approach does not work; migration plan will fail at this step | Phase 0 | Medium | Update plan with correct approach (new RG + resource move/recreate) |

### P3 — Medium

| # | Finding | Affected Task | Impact | Required Action |
|---|---------|--------------|--------|----------------|
| P3-REVIEW-01 | **Key Vault diagnostic settings missing** — access audit trail not captured | Phase 0 task 0.7 | Medium | Add KV `AuditEvent` to Phase 0 diagnostic settings configuration |
| P3-REVIEW-02 | **App Insights sampling not specified** — potential unanticipated cost at scale | Phase 2 task 2.6 | Low-Medium | Define sampling rate in Phase 2 SDK configuration |
| P3-REVIEW-03 | **Migration artifact names** — `cae-*-new` and `srch-*-basic` are non-CAF | Phase 1/2 naming | Low | Create AI Search as `srch-ai-dev-sdc-02` directly; document CAE FQDN impact |
| P3-REVIEW-04 | **No Bing API key rotation schedule** | Phase 3 | Medium | Add key rotation schedule + KV expiry alert to Phase 3 tasks |
| P3-REVIEW-05 | **No drift detection** in CI/CD | Phase 3 task 3.8 | Medium | Add scheduled `az deployment what-if` to GitHub Actions pipeline |
| P3-REVIEW-06 | **No pre-migration performance baseline** | Phase 0 | Medium | Add baseline load test task to Phase 0 |
| P3-REVIEW-07 | **No caching layer** — AI API costs and latency unoptimized | Phase 3 | Low-Medium | Evaluate APIM Consumption tier in Phase 3 |

### P4 — Low

| # | Finding | Affected Task | Impact | Required Action |
|---|---------|--------------|--------|----------------|
| P4-REVIEW-01 | **APIM semantic caching not planned** | Post-Phase 3 | Low | Promote from backlog to Phase 3 evaluation |
| P4-REVIEW-02 | **AI Search Basic single partition** — throughput bottleneck possible | Phase 1 | Low | Add second replica to AI Search Basic after performance baseline |
| P4-REVIEW-03 | **Container App resource sizing not re-evaluated** | Phase 2 | Low | Monitor CPU/memory post-migration; adjust if P95 CPU > 70% |
| P4-REVIEW-04 | **AVM modules not specified for new resources** | Phase 3 task 3.8 | Low | Use AVM modules for VNet, PE, KV, NSG Bicep; pin versions |

---

## 7. Recommendations Summary

### Changes Required Before Implementation Begins

| Priority | Action | Phase Impact |
|----------|--------|-------------|
| **🔴 P1** | Add NSGs (`nsg-app-dev-sdc-02`, `nsg-pe-dev-sdc-02`) to Phase 1 VNet task | Update Phase 1 task 1.1 |
| **🔴 P1** | Correct the Resource Group rename description — replace with "create new RG + resource move/recreate" approach | Update migration map + Phase 0 |
| **🟠 P2** | Add Azure Monitor Private Link Scope + PE (`pep-mon-dev-sdc-02`) to Phase 1 network plan | Update Phase 1 task list |
| **🟠 P2** | Add application-layer egress controls for Bing outbound traffic | Update Phase 2 task 2.2 |

### Changes Recommended Before Phase 3 Complete

| Priority | Action | Phase |
|----------|--------|-------|
| **🟠 P3** | Add KV diagnostic settings to Phase 0 task 0.7 | Phase 0 |
| **🟠 P3** | Add pre-migration performance baseline to Phase 0 | Phase 0 (new task 0.0) |
| **🟠 P3** | Create AI Search as `srch-ai-dev-sdc-02` (remove `-basic` suffix) | Phase 1 task 1.7 |
| **🟠 P3** | Define App Insights sampling rate in Phase 2 SDK setup | Phase 2 task 2.6 |
| **🟠 P3** | Add Bing API key rotation schedule + KV expiry alert to Phase 3 | Phase 3 (new task) |
| **🟠 P3** | Add drift detection workflow to CI/CD in Phase 3 | Phase 3 task 3.8 |

---

## 8. Questions for the Team

1. **Resource Group rename**: Is achieving the CAF-correct name `rg-ai-dev-sdc-02` a hard requirement, or is the existing name `rg-dev-ai-sdc-02` acceptable as a known deviation? This significantly impacts migration complexity.
2. **Azure Firewall**: Is a full Azure Firewall in scope for the production hardening, or will application-layer egress controls suffice? Azure Firewall Standard adds ~$900/month.
3. **Hub-and-spoke networking**: Does the DEV-PWR subscription already have a hub VNet or central DNS/Firewall infrastructure? If so, the target architecture should peer to the hub rather than creating standalone DNS zones.
4. **AI Search single vs. two replicas**: Is 99.9% SLA (single replica Basic) acceptable, or does the workload require the higher availability of two replicas at ~$146/month?
5. **Multi-region**: Is there a production readiness timeline? If production promotion is planned within 6 months, multi-region design should be started now rather than after the uplift is complete.
6. **APIM**: Is Azure API Management already deployed elsewhere in the subscription? If so, adding a new product/API is far cheaper than deploying a new instance.

---

## 9. Overall Verdict

The proposed target architecture is **approved with required changes**. The two P1 findings (missing NSGs, incorrect RG rename approach) must be corrected in the migration plan before Phase 1 begins. The P2 findings (AMPLS private endpoint, egress controls) should be incorporated into Phase 1 to maintain the design's internal consistency of "no public egress from within the VNet."

Once the P1 and P2 gaps are addressed, the projected WAF score improves from ~79 to approximately **85/100** — a production-ready posture appropriate for a development workload that may be promoted to staging/production.

| Decision | Verdict |
|----------|---------|
| Architecture direction | ✅ Approved |
| Network design | ⚠️ Approved with required changes (add NSGs, AMPLS) |
| Identity design | ✅ Approved |
| Cost model | ✅ Approved |
| Migration phasing | ⚠️ Approved with required changes (correct RG approach, artifact naming) |

---

*Review by GitHub Copilot Reviewer Agent — 2026-03-15. Based on `discovery/docs/migration-plan.md`. Source files: `discovery-inventory.md`, `waf-assessment.md`, `discovery-report.md`.*
