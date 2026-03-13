# Deployment Guide — Todo Application Infrastructure

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Environment Configuration](#environment-configuration)
- [Step-by-Step Deployment](#step-by-step-deployment)
- [Post-Deployment Steps](#post-deployment-steps)
- [Post-Deployment Verification](#post-deployment-verification)
- [Rollback Procedures](#rollback-procedures)
- [CI/CD Pipeline](#cicd-pipeline)
- [Troubleshooting Deployment Issues](#troubleshooting-deployment-issues)

---

## Overview

This guide covers deploying the Todo application infrastructure to Azure using Bicep. The deployment creates 29 resources in the `norwayeast` region within a single resource group.

**Deployment scope:** Subscription-level (`targetScope = 'subscription'`)
**Target resource group:** `rg-todo-dev-norwayeast`
**Estimated deployment time:** 10–15 minutes

---

## Prerequisites

### Required Tools

| Tool | Minimum Version | Verify | Install |
|------|----------------|--------|---------|
| Azure CLI | 2.60+ | `az version` | [Install](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Bicep CLI | 0.25+ | `az bicep version` | `az bicep install` |

### Required Azure Permissions

| Permission | Scope | Purpose |
|-----------|-------|---------|
| **Contributor** | Subscription | Create resource group and resources |
| **User Access Administrator** | Subscription | Assign Managed Identity roles |
| **Directory Reader** | Entra ID | Resolve Entra ID object IDs for SQL admin |

### Required Information

| Item | Description | How to Obtain |
|------|-------------|---------------|
| Subscription ID | Azure subscription for deployment | `az account show --query id -o tsv` |
| Entra ID Object ID | Object ID of user/group for SQL admin | `az ad signed-in-user show --query id -o tsv` |

---

## Pre-Deployment Checklist

- [ ] Azure CLI installed and updated (`az upgrade`)
- [ ] Bicep CLI installed (`az bicep install`)
- [ ] Logged in to Azure (`az login`)
- [ ] Correct subscription selected (`az account set --subscription "<id>"`)
- [ ] Entra ID Object ID obtained for SQL admin
- [ ] Verify `norwayeast` region supports required services:
  ```bash
  az provider show --namespace Microsoft.Sql --query "resourceTypes[?resourceType=='servers'].locations" -o tsv | grep -i norway
  ```
- [ ] Sufficient quota for resources (1 App Service Plan, 1 SQL Server)
- [ ] No naming conflicts (resource names must be globally unique for SQL Server and App Service):
  ```bash
  az webapp show --name app-todo-dev-norwayeast --resource-group rg-todo-dev-norwayeast 2>&1 | grep -q "not found" && echo "Name available"
  ```

---

## Environment Configuration

### Parameter File (`iac/infra/main.bicepparam`)

The parameter file defines environment-specific values. Current configuration targets **dev**:

| Parameter | Dev Value | Staging | Production |
|-----------|-----------|---------|------------|
| `location` | `norwayeast` | `norwayeast` | `norwayeast` |
| `environment` | `dev` | `staging` | `prod` |
| `workload` | `todo` | `todo` | `todo` |
| `sqlAdminLoginName` | `sqladmin-entra` | `sqladmin-entra` | `sqladmin-entra` |

### Tags

| Tag | Dev | Staging | Production |
|-----|-----|---------|------------|
| `environment` | `dev` | `staging` | `prod` |
| `workload` | `todo` | `todo` | `todo` |
| `owner` | `hackathon-team` | `hackathon-team` | `platform-team` |
| `costCenter` | `hackathon-2026` | `hackathon-2026` | `prod-budget` |

### Creating Additional Environment Parameter Files

To deploy to a different environment, create a new `.bicepparam` file:

```bicepparam
using './main.bicep'

param location = 'norwayeast'
param environment = 'staging'
param workload = 'todo'
param sqlAdminObjectId = '<staging-entra-id-object-id>'
param sqlAdminLoginName = 'sqladmin-entra'
param tags = {
  environment: 'staging'
  workload: 'todo'
  owner: 'hackathon-team'
  costCenter: 'hackathon-2026'
}
```

---

## Step-by-Step Deployment

### Step 1: Authenticate

```bash
# Login to Azure
az login

# Verify your account
az account show --query "{name:name, id:id, tenantId:tenantId}" -o table

# Set the target subscription
az account set --subscription "<your-subscription-id>"
```

### Step 2: Validate the template

```bash
# Lint the Bicep files
az bicep lint --file iac/infra/main.bicep

# Build to check for compilation errors
az bicep build --file iac/infra/main.bicep
```

**Expected output:** No errors or warnings.

### Step 3: Preview changes with What-If

```bash
# Get your Entra ID object ID
SQL_ADMIN_OID=$(az ad signed-in-user show --query id -o tsv)

# Run what-if to preview resource changes
az deployment sub what-if \
  --location norwayeast \
  --template-file iac/infra/main.bicep \
  --parameters iac/infra/main.bicepparam \
  --parameters sqlAdminObjectId="$SQL_ADMIN_OID"
```

**Expected output:** 29 resources with `+ Create` status. No modifications or deletions.

Review the output carefully. Verify:
- Resource names follow CAF naming conventions
- SKUs match expected values (B1 for App Service, Basic for SQL)
- No unexpected resources are being created or destroyed

### Step 4: Deploy

```bash
# Deploy the infrastructure
az deployment sub create \
  --name "todo-dev-$(date +%Y%m%d-%H%M%S)" \
  --location norwayeast \
  --template-file iac/infra/main.bicep \
  --parameters iac/infra/main.bicepparam \
  --parameters sqlAdminObjectId="$SQL_ADMIN_OID"
```

**Expected output:** Deployment succeeds with `provisioningState: Succeeded`.

### Step 5: Capture deployment outputs

```bash
# Get deployment outputs
az deployment sub show \
  --name "$(az deployment sub list --location norwayeast --query "[0].name" -o tsv)" \
  --query properties.outputs -o json
```

Key outputs to note:
- `appServiceDefaultHostname` — URL for the web app
- `appServicePrincipalId` — Managed Identity principal ID (needed for SQL role grant)
- `sqlServerFqdn` — SQL Server FQDN

---

## Post-Deployment Steps

### Step 6: Grant Managed Identity SQL access

The Web App's Managed Identity needs database-level roles. This **cannot** be done via Bicep and must be run as a SQL script.

1. Get the Web App name (used as the identity name):
   ```bash
   az webapp show \
     --resource-group rg-todo-dev-norwayeast \
     --name app-todo-dev-norwayeast \
     --query name -o tsv
   ```

2. Connect to `sqldb-todo-dev-norwayeast` as the Entra ID admin using Azure Data Studio, SSMS, or `sqlcmd`:
   ```bash
   # Using sqlcmd with Entra ID authentication
   sqlcmd -S sql-todo-dev-norwayeast.database.windows.net \
     -d sqldb-todo-dev-norwayeast \
     --authentication-method=ActiveDirectoryDefault
   ```

3. Run the SQL script:
   ```sql
   CREATE USER [app-todo-dev-norwayeast] FROM EXTERNAL PROVIDER;
   ALTER ROLE db_datareader ADD MEMBER [app-todo-dev-norwayeast];
   ALTER ROLE db_datawriter ADD MEMBER [app-todo-dev-norwayeast];
   GO
   ```

> **Note:** You must be connected through a machine that can reach the SQL Server via the Private Endpoint (within the VNet or via VPN/ExpressRoute), since public access is disabled.

### Step 7: Deploy the application code

Deploy the Todo application to the App Service:

```bash
# Example: deploy a .NET 8 app from a publish folder
az webapp deploy \
  --resource-group rg-todo-dev-norwayeast \
  --name app-todo-dev-norwayeast \
  --src-path ./app/publish.zip \
  --type zip
```

---

## Post-Deployment Verification

### 1. Verify resource group

```bash
az group show --name rg-todo-dev-norwayeast --query "{name:name, location:location, provisioningState:properties.provisioningState}" -o table
```

### 2. Verify App Service is running

```bash
az webapp show \
  --resource-group rg-todo-dev-norwayeast \
  --name app-todo-dev-norwayeast \
  --query "{name:name, state:state, defaultHostName:defaultHostName}" -o table
```

### 3. Verify SQL Server has no public access

```bash
az sql server show \
  --resource-group rg-todo-dev-norwayeast \
  --name sql-todo-dev-norwayeast \
  --query "{name:name, publicNetworkAccess:publicNetworkAccess, minimalTlsVersion:minimalTlsVersion}" -o table
```

**Expected:** `publicNetworkAccess: Disabled`, `minimalTlsVersion: 1.2`

### 4. Verify Private Endpoint

```bash
az network private-endpoint show \
  --resource-group rg-todo-dev-norwayeast \
  --name pep-sql-dev-norwayeast \
  --query "{name:name, provisioningState:provisioningState, privateLinkServiceConnectionState:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" -o table
```

**Expected:** `provisioningState: Succeeded`, connection state: `Approved`

### 5. Verify NSGs

```bash
# App subnet NSG
az network nsg show \
  --resource-group rg-todo-dev-norwayeast \
  --name nsg-app-dev-norwayeast \
  --query "securityRules[].{name:name, priority:priority, direction:direction, access:access}" -o table

# PE subnet NSG
az network nsg show \
  --resource-group rg-todo-dev-norwayeast \
  --name nsg-pe-dev-norwayeast \
  --query "securityRules[].{name:name, priority:priority, direction:direction, access:access}" -o table
```

### 6. Verify health endpoint

```bash
curl -s -o /dev/null -w "%{http_code}" https://app-todo-dev-norwayeast.azurewebsites.net/health
```

**Expected:** HTTP `200` (after application code is deployed and SQL role granted).

### 7. Verify monitoring

```bash
# Check Application Insights exists
az monitor app-insights component show \
  --resource-group rg-todo-dev-norwayeast \
  --app appi-todo-dev-norwayeast \
  --query "{name:name, provisioningState:provisioningState}" -o table

# Check Log Analytics Workspace
az monitor log-analytics workspace show \
  --resource-group rg-todo-dev-norwayeast \
  --workspace-name law-todo-dev-norwayeast \
  --query "{name:name, provisioningState:provisioningState, sku:sku.name}" -o table
```

### Verification Summary

| Check | Command | Expected |
|-------|---------|----------|
| Resource Group | `az group show` | `provisioningState: Succeeded` |
| App Service | `az webapp show` | `state: Running` |
| SQL public access | `az sql server show` | `publicNetworkAccess: Disabled` |
| Private Endpoint | `az network private-endpoint show` | `provisioningState: Succeeded` |
| NSGs | `az network nsg show` | 6+ rules across both NSGs |
| Health endpoint | `curl /health` | HTTP 200 |
| App Insights | `az monitor app-insights component show` | `provisioningState: Succeeded` |

---

## Rollback Procedures

### Option 1: Delete the entire resource group (full rollback)

If the deployment needs to be completely removed:

```bash
az group delete --name rg-todo-dev-norwayeast --yes --no-wait
```

> **Warning:** This deletes all resources in the group permanently. SQL Database backups are retained per the configured retention period (7 days for dev).

### Option 2: Redeploy a previous version

If you need to revert to a previous configuration:

```bash
# List recent deployments
az deployment sub list --location norwayeast --query "[].{name:name, timestamp:properties.timestamp, state:properties.provisioningState}" -o table

# Redeploy from a known-good template version
git checkout <known-good-commit> -- iac/infra/
az deployment sub create \
  --name "todo-dev-rollback-$(date +%Y%m%d-%H%M%S)" \
  --location norwayeast \
  --template-file iac/infra/main.bicep \
  --parameters iac/infra/main.bicepparam \
  --parameters sqlAdminObjectId="$SQL_ADMIN_OID"
```

### Option 3: Restore SQL Database (data rollback)

If only the database needs to be restored:

```bash
# Point-in-time restore (within 7-day retention)
az sql db restore \
  --resource-group rg-todo-dev-norwayeast \
  --server sql-todo-dev-norwayeast \
  --name sqldb-todo-dev-norwayeast \
  --dest-name sqldb-todo-dev-norwayeast-restored \
  --time "2026-03-12T12:00:00Z"
```

---

## CI/CD Pipeline

### PR Validation Workflow

On every pull request to `main`, the following checks run:

1. **Lint** — `az bicep lint` on all `.bicep` files
2. **Build** — `az bicep build` on `main.bicep`
3. **What-If** — `az deployment sub what-if` to preview changes

### Deployment Workflow

On push to `main`:

1. **Build** — Compile Bicep to ARM template
2. **Deploy** — `az deployment sub create` targeting `norwayeast`

### Running CI/CD checks locally

```bash
# Lint
az bicep lint --file iac/infra/main.bicep

# Build
az bicep build --file iac/infra/main.bicep

# What-If
az deployment sub what-if \
  --location norwayeast \
  --template-file iac/infra/main.bicep \
  --parameters iac/infra/main.bicepparam \
  --parameters sqlAdminObjectId="$SQL_ADMIN_OID"
```

---

## Troubleshooting Deployment Issues

### "The subscription is not registered for resource type"

```bash
az provider register --namespace Microsoft.Sql
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.OperationalInsights
```

### "The resource name is already in use"

SQL Server and App Service names must be globally unique. If `sql-todo-dev-norwayeast` is taken, update the `workload` parameter to create unique names.

### "InsufficientPermissions" on Managed Identity

Ensure your account has **User Access Administrator** at the subscription level, or request the role from your Azure admin.

### Private Endpoint connection stuck in "Pending"

Private Endpoints to Azure SQL should auto-approve. If stuck:

```bash
az network private-endpoint-connection list \
  --resource-group rg-todo-dev-norwayeast \
  --name sql-todo-dev-norwayeast \
  --type Microsoft.Sql/servers -o table
```

### Deployment timeout

Individual Bicep deployments have a 2-hour default timeout. If the deployment is slow:

```bash
# Check deployment operations for failures
az deployment sub operation list \
  --name "<deployment-name>" \
  --query "[?properties.provisioningState!='Succeeded'].{resource:properties.targetResource.resourceType, state:properties.provisioningState, error:properties.statusMessage.error.message}" -o table
```
