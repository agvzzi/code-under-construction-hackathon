# Operations Runbook — Todo Application Infrastructure

## Table of Contents

- [Overview](#overview)
- [Resource Summary](#resource-summary)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Day-to-Day Operations](#day-to-day-operations)
- [Common Troubleshooting Scenarios](#common-troubleshooting-scenarios)
- [Scaling Procedures](#scaling-procedures)
- [Backup and Restore](#backup-and-restore)
- [Security Incident Response](#security-incident-response)
- [Maintenance Windows](#maintenance-windows)
- [Contact Information](#contact-information)

---

## Overview

This runbook covers operational procedures for the Todo application infrastructure deployed in `rg-todo-dev-norwayeast` on Azure Norway East. All resources are deployed via Bicep IaC — manual changes in the portal should be avoided.

**Architecture:** [architecture.md](architecture.md)
**Deployment Guide:** [deployment-guide.md](deployment-guide.md)

---

## Resource Summary

| Resource | Name | Purpose |
|----------|------|---------|
| App Service | `app-todo-dev-norwayeast` | Hosts the .NET 8 Todo web application |
| App Service Plan | `asp-todo-dev-norwayeast` | Compute plan (B1 — 1 core, 1.75 GB) |
| SQL Server | `sql-todo-dev-norwayeast` | Database server (Entra-only auth) |
| SQL Database | `sqldb-todo-dev-norwayeast` | Todo data (Basic, 5 DTU) |
| Virtual Network | `vnet-todo-dev-norwayeast` | Network isolation (10.0.0.0/16) |
| Private Endpoint | `pep-sql-dev-norwayeast` | Private SQL connectivity |
| Log Analytics | `law-todo-dev-norwayeast` | Centralized log storage |
| Application Insights | `appi-todo-dev-norwayeast` | APM and telemetry |

---

## Monitoring and Alerting

### Dashboards

| Tool | URL | Purpose |
|------|-----|---------|
| Azure Portal — Resource Group | `portal.azure.com → rg-todo-dev-norwayeast` | Overview of all resources |
| Application Insights | `portal.azure.com → appi-todo-dev-norwayeast` | App performance, failures, dependencies |
| Log Analytics | `portal.azure.com → law-todo-dev-norwayeast` | Log queries, custom dashboards |

### Alert Rules

8 metric alerts are configured. All fire when thresholds are breached within a 5-minute evaluation window.

#### App Service Alerts

| Alert | Metric | Threshold | Severity | Action |
|-------|--------|-----------|----------|--------|
| High CPU | `CpuPercentage` | > 80% avg for 5 min | Sev 2 | Investigate process, consider scaling |
| HTTP 5xx Errors | `Http5xx` | > 5 total in 5 min | Sev 1 | Check app logs, recent deployments |
| Slow Response Time | `HttpResponseTime` | > 2s avg for 5 min | Sev 2 | Check SQL performance, dependencies |
| Health Check Failure | `HealthCheckStatus` | < 100% for 5 min | Sev 1 | Check DB connectivity, app health |

#### SQL Database Alerts

| Alert | Metric | Threshold | Severity | Action |
|-------|--------|-----------|----------|--------|
| High DTU Usage | `dtu_consumption_percent` | > 80% avg for 5 min | Sev 2 | Identify heavy queries, consider scaling |
| Failed Connections | `connection_failed` | > 10 total in 5 min | Sev 1 | Check firewall rules, PE connectivity |
| Deadlocks | `deadlock` | > 0 in 5 min | Sev 2 | Review transaction patterns |
| High Storage | `storage_percent` | > 80% max | Sev 3 | Clean up data or increase DB size |

### Useful Log Analytics (KQL) Queries

#### App Service errors in the last hour

```kql
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| where ScStatus >= 500
| summarize count() by ScStatus, CsUriStem
| order by count_ desc
```

#### App Service slow requests

```kql
AppServiceHTTPLogs
| where TimeGenerated > ago(1h)
| where TimeTaken > 2000
| project TimeGenerated, CsUriStem, ScStatus, TimeTaken
| order by TimeTaken desc
```

#### SQL failed connections

```kql
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.SQL"
| where Category == "SQLSecurityAuditEvents"
| where TimeGenerated > ago(1h)
| where action_name_s == "FAILED_LOGIN"
| summarize count() by client_ip_s, server_principal_name_s
```

#### Health check status over time

```kql
AppServiceHTTPLogs
| where CsUriStem == "/health"
| where TimeGenerated > ago(24h)
| summarize HealthyCount=countif(ScStatus == 200), UnhealthyCount=countif(ScStatus != 200) by bin(TimeGenerated, 5m)
| render timechart
```

---

## Day-to-Day Operations

### Check application status

```bash
# App Service state
az webapp show --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast --query state -o tsv

# Health endpoint
curl -s -w "\nHTTP %{http_code}\n" https://app-todo-dev-norwayeast.azurewebsites.net/health
```

### View application logs

```bash
# Stream live logs
az webapp log tail --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast

# Download recent logs
az webapp log download --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast --log-file logs.zip
```

### Restart the App Service

```bash
az webapp restart --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast
```

### Check SQL Database DTU usage

```bash
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/rg-todo-dev-norwayeast/providers/Microsoft.Sql/servers/sql-todo-dev-norwayeast/databases/sqldb-todo-dev-norwayeast" \
  --metric "dtu_consumption_percent" \
  --interval PT5M \
  --query "value[0].timeseries[0].data[-5:].{time:timeStamp, dtu:average}" -o table
```

### Deploy application update

```bash
az webapp deploy \
  --resource-group rg-todo-dev-norwayeast \
  --name app-todo-dev-norwayeast \
  --src-path ./app/publish.zip \
  --type zip
```

---

## Common Troubleshooting Scenarios

### Scenario 1: Health check failing (503 errors)

**Symptoms:** Alert `Health Check Failure` fires. App returns 503.

**Diagnosis:**
```bash
# Check app state
az webapp show --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast --query state -o tsv

# Check recent restarts
az webapp log tail --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast --filter "Health"
```

**Common causes:**
1. **SQL Database unreachable** — Check Private Endpoint status and NSG rules
2. **Managed Identity not configured in SQL** — Re-run the SQL role grant script
3. **Application crash** — Check AppServiceConsoleLogs in Log Analytics
4. **Out of memory** — Check B1 plan memory usage, consider scaling

**Resolution:**
```bash
# Restart the app
az webapp restart --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast

# If restart doesn't help, check Private Endpoint
az network private-endpoint show --resource-group rg-todo-dev-norwayeast --name pep-sql-dev-norwayeast --query "privateLinkServiceConnections[0].privateLinkServiceConnectionState" -o json
```

### Scenario 2: High DTU usage on SQL Database

**Symptoms:** Alert `High DTU Usage` fires. Application becomes slow.

**Diagnosis:**
```bash
# Check current DTU usage
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/rg-todo-dev-norwayeast/providers/Microsoft.Sql/servers/sql-todo-dev-norwayeast/databases/sqldb-todo-dev-norwayeast" \
  --metric "dtu_consumption_percent" \
  --interval PT1M \
  --query "value[0].timeseries[0].data[-10:].{time:timeStamp, dtu:average}" -o table
```

**Common causes:**
1. Inefficient query without indexes
2. Long-running transactions causing blocking
3. Unexpected traffic spike

**Resolution:**
- Use SQL Insights in Log Analytics to identify expensive queries
- For immediate relief, consider temporarily scaling the database (see [Scaling Procedures](#scaling-procedures))

### Scenario 3: HTTP 5xx errors spike

**Symptoms:** Alert `HTTP 5xx Errors` fires.

**Diagnosis:**
```kql
AppServiceHTTPLogs
| where TimeGenerated > ago(30m)
| where ScStatus >= 500
| summarize count() by ScStatus, CsUriStem, bin(TimeGenerated, 1m)
| render timechart
```

**Common causes:**
1. Application exception (unhandled errors)
2. Database connectivity issues
3. Deployment in progress

**Resolution:**
- Check Application Insights → Failures blade for exception details
- If caused by a bad deployment, rollback (see [Deployment Guide](deployment-guide.md#rollback-procedures))

### Scenario 4: Cannot connect to SQL from App Service

**Symptoms:** Application errors referencing SQL connectivity.

**Diagnosis:**
```bash
# Verify Private Endpoint
az network private-endpoint show --resource-group rg-todo-dev-norwayeast --name pep-sql-dev-norwayeast --query provisioningState -o tsv

# Verify DNS resolution (from within VNet)
nslookup sql-todo-dev-norwayeast.database.windows.net

# Check NSG rules
az network nsg rule list --resource-group rg-todo-dev-norwayeast --nsg-name nsg-app-dev-norwayeast -o table
```

**Common causes:**
1. Private DNS Zone not linked to VNet
2. NSG blocking port 1433 outbound from app subnet
3. Managed Identity role not granted in SQL Database

---

## Scaling Procedures

### Scale App Service Plan

```bash
# Scale up (vertical) — change SKU
az appservice plan update \
  --resource-group rg-todo-dev-norwayeast \
  --name asp-todo-dev-norwayeast \
  --sku S1

# Scale out (horizontal) — add instances (requires S1+)
az appservice plan update \
  --resource-group rg-todo-dev-norwayeast \
  --name asp-todo-dev-norwayeast \
  --number-of-workers 2
```

| SKU | vCPU | Memory | Auto-scale | Monthly Cost |
|-----|------|--------|------------|-------------|
| B1 (current) | 1 | 1.75 GB | No | ~$13 |
| S1 | 1 | 1.75 GB | Yes | ~$73 |
| P1v3 | 2 | 8 GB | Yes + zones | ~$138 |

> **Note:** Scaling should be done via Bicep (update `skuName` in `webapp.bicep`) to maintain IaC consistency. Use CLI only for emergency scaling.

### Scale SQL Database

```bash
# Scale to Standard S2 (50 DTU)
az sql db update \
  --resource-group rg-todo-dev-norwayeast \
  --server sql-todo-dev-norwayeast \
  --name sqldb-todo-dev-norwayeast \
  --edition Standard \
  --capacity 50

# Scale back to Basic (5 DTU)
az sql db update \
  --resource-group rg-todo-dev-norwayeast \
  --server sql-todo-dev-norwayeast \
  --name sqldb-todo-dev-norwayeast \
  --edition Basic \
  --capacity 5
```

| Tier | DTU | Max Size | Monthly Cost |
|------|-----|----------|-------------|
| Basic (current) | 5 | 2 GB | ~$5 |
| Standard S0 | 10 | 250 GB | ~$15 |
| Standard S2 | 50 | 250 GB | ~$75 |

---

## Backup and Restore

### SQL Database Backups

Azure SQL Database backups are **automatic** and require no configuration:

| Property | Dev Value | Production Recommended |
|----------|-----------|----------------------|
| Backup type | Full, differential, transaction log | Same |
| Retention | 7 days | 35 days |
| RPO | 5 minutes | 5 minutes |
| RTO | 30 minutes | 30 minutes |
| Geo-redundant | No | Yes |

#### Point-in-Time Restore

```bash
# Restore to a specific point in time
az sql db restore \
  --resource-group rg-todo-dev-norwayeast \
  --server sql-todo-dev-norwayeast \
  --name sqldb-todo-dev-norwayeast \
  --dest-name sqldb-todo-dev-norwayeast-restored \
  --time "2026-03-12T12:00:00Z"
```

#### After restore: switch the application

1. Update the connection string in the Web App to point to the restored database, or
2. Rename the restored database to the original name (after dropping/renaming the old one)

### App Service Backups

App Service on B1 does not include built-in backup. The application should be redeployable from source at any time via the CI/CD pipeline or manual `az webapp deploy`.

---

## Security Incident Response

### 1. Suspicious SQL Activity

Azure Defender for SQL is enabled and will alert on:
- SQL injection attempts
- Anomalous database access patterns
- Brute force login attempts

**Response steps:**
1. Check Azure Defender alerts in Azure Portal → Security Center
2. Review audit logs:
   ```kql
   AzureDiagnostics
   | where ResourceProvider == "MICROSOFT.SQL"
   | where Category == "SQLSecurityAuditEvents"
   | where TimeGenerated > ago(1h)
   | order by TimeGenerated desc
   ```
3. If compromise suspected, rotate the Entra ID admin credentials
4. Review NSG flow logs for unexpected traffic patterns

### 2. Unauthorized Access Attempt

1. Check App Service access logs for suspicious requests
2. Review Entra ID sign-in logs for the SQL admin account
3. Verify NSG rules haven't been modified outside IaC

### 3. Emergency lockdown

If immediate isolation is required:

```bash
# Stop the App Service (stops all traffic)
az webapp stop --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast

# Verify it's stopped
az webapp show --resource-group rg-todo-dev-norwayeast --name app-todo-dev-norwayeast --query state -o tsv
```

---

## Maintenance Windows

### Recommended maintenance schedule

| Task | Frequency | Impact |
|------|-----------|--------|
| Review alert rules | Weekly | None |
| Check Log Analytics retention | Monthly | None |
| Review SQL Insights (expensive queries) | Weekly | None |
| Update AVM module versions | Monthly | Requires redeployment |
| Rotate Entra ID admin if needed | Quarterly | Brief SQL admin access interruption |
| Review NSG rules | Monthly | None |
| Test backup restore procedure | Quarterly | Creates temporary restored DB |

### Azure platform maintenance

Azure manages platform updates automatically. App Service instances may restart during platform updates. The health check at `/health` ensures traffic is only routed to healthy instances.

---

## Contact Information

| Role | Name | Contact |
|------|------|---------|
| Infrastructure Owner | *hackathon-team* | *TBD* |
| Application Owner | *hackathon-team* | *TBD* |
| Azure Admin | *TBD* | *TBD* |
| Security Contact | *TBD* | *TBD* |

> **Update this section** with actual team contacts before promoting to production.
