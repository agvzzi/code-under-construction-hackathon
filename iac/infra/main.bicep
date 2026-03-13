// ============================================================================
// Main Bicep Orchestration — Todo Application Infrastructure
// Description: Deploys all modules in dependency order for the Todo application
// ============================================================================

targetScope = 'subscription'

// Parameters
// ============================================================================

@description('Azure region for all resources.')
param location string

@description('Environment name (dev, staging, prod).')
param environment string

@description('Workload name used in resource naming.')
param workload string

@description('Object ID of the Entra ID group/user for SQL Server admin.')
param sqlAdminObjectId string

@description('Display name of the Entra ID administrator for SQL Server.')
param sqlAdminLoginName string = 'sqladmin-entra'

@description('Tags to apply to all resources.')
param tags object

// Variables
// ============================================================================

var resourceGroupName = 'rg-${workload}-${environment}-${location}'

// Resource Group
// ============================================================================

module resourceGroup 'br/public:avm/res/resources/resource-group:0.4.1' = {
  name: '${resourceGroupName}-deployment'
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

// Layer 1: Networking (VNet, Subnets, NSGs)
// ============================================================================

module networking 'modules/networking.bicep' = {
  name: 'networking-deployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    location: location
    environment: environment
    workload: workload
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

// Layer 2: Monitoring (Log Analytics, Application Insights)
// Parallel with Layer 1 — no dependency on networking
// ============================================================================

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    location: location
    environment: environment
    workload: workload
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

// Layer 3: Data (SQL Server, SQL Database, Private Endpoint, Private DNS Zone)
// Depends on networking (subnet for PE, VNet for DNS) and monitoring (LAW)
// ============================================================================

module database 'modules/database.bicep' = {
  name: 'database-deployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    location: location
    environment: environment
    workload: workload
    tags: tags
    sqlAdminObjectId: sqlAdminObjectId
    sqlAdminLoginName: sqlAdminLoginName
    subnetPeResourceId: networking.outputs.subnetPeResourceId
    vnetResourceId: networking.outputs.vnetResourceId
  }
}

// Layer 4: Compute (App Service Plan, Web App, VNet Integration)
// Depends on networking (subnet), monitoring (App Insights), database (SQL FQDN)
// ============================================================================

module webapp 'modules/webapp.bicep' = {
  name: 'webapp-deployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    location: location
    environment: environment
    workload: workload
    tags: tags
    subnetAppResourceId: networking.outputs.subnetAppResourceId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    sqlServerFqdn: database.outputs.sqlServerFqdn
    sqlDatabaseName: database.outputs.sqlDatabaseName
  }
}

// Layer 5: Alerting & Diagnostics
// Depends on webapp and database resource IDs for scoping alerts and diagnostics
// ============================================================================

module alerts 'modules/alerts.bicep' = {
  name: 'alerts-deployment'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    environment: environment
    workload: workload
    tags: tags
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appServiceResourceId: webapp.outputs.appServiceResourceId
    appServiceName: webapp.outputs.appServiceName
    sqlDatabaseResourceId: database.outputs.sqlDatabaseResourceId
    sqlServerName: database.outputs.sqlServerName
    sqlDatabaseName: database.outputs.sqlDatabaseName
  }
}

// Outputs
// ============================================================================

@description('Name of the resource group.')
output resourceGroupName string = resourceGroupName

@description('Resource ID of the Virtual Network.')
output vnetResourceId string = networking.outputs.vnetResourceId

@description('Default hostname of the Web App.')
output appServiceDefaultHostname string = webapp.outputs.appServiceDefaultHostname

@description('Principal ID of the Web App Managed Identity (for post-deployment SQL role grant).')
output appServicePrincipalId string = webapp.outputs.appServicePrincipalId

@description('SQL Server FQDN.')
output sqlServerFqdn string = database.outputs.sqlServerFqdn

@description('Application Insights connection string.')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('Log Analytics Workspace ID.')
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
