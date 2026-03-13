// ============================================================================
// Module: webapp.bicep
// Description: App Service Plan, Web App with VNet Integration,
//              Managed Identity, Health Check
// ============================================================================

// Parameters
// ============================================================================

@description('Azure region for all resources.')
param location string

@description('Environment name (dev, staging, prod).')
param environment string

@description('Workload name used in resource naming.')
param workload string

@description('Tags to apply to all resources.')
param tags object

@description('Resource ID of the App Service subnet for VNet integration.')
param subnetAppResourceId string

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Fully qualified domain name of the SQL Server.')
param sqlServerFqdn string

@description('Name of the SQL Database.')
param sqlDatabaseName string

// Variables
// ============================================================================

var aspName = 'asp-${workload}-${environment}-${location}'
var appName = 'app-${workload}-${environment}-${location}'
var sqlConnectionString = 'Server=tcp:${sqlServerFqdn},1433;Initial Catalog=${sqlDatabaseName};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

// Resources
// ============================================================================

// App Service Plan (Linux, B1)
module appServicePlan 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: '${aspName}-deployment'
  params: {
    name: aspName
    location: location
    tags: tags
    skuName: 'B1'
    skuCapacity: 1
    kind: 'linux'
    reserved: true
  }
}

// Web App with Managed Identity, VNet Integration, and Health Check
module webApp 'br/public:avm/res/web/site:0.12.0' = {
  name: '${appName}-deployment'
  params: {
    name: appName
    location: location
    tags: tags
    kind: 'app,linux'
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    virtualNetworkSubnetId: subnetAppResourceId
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      healthCheckPath: '/health'
      linuxFxVersion: 'DOTNETCORE|8.0'
      alwaysOn: false // B1 supports alwaysOn but keeping off for dev cost savings
      vnetRouteAllEnabled: true
    }
    appSettingsKeyValuePairs: {
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
      WEBSITE_VNET_ROUTE_ALL: '1'
      SQLAZURECONNSTR_DefaultConnection: sqlConnectionString
    }
  }
}

// Post-deployment note: The Web App's Managed Identity must be granted
// database roles via SQL script after deployment:
//
// -- Run this SQL script against sqldb-todo-dev-norwayeast as the Entra ID admin:
// CREATE USER [app-todo-dev-norwayeast] FROM EXTERNAL PROVIDER;
// ALTER ROLE db_datareader ADD MEMBER [app-todo-dev-norwayeast];
// ALTER ROLE db_datawriter ADD MEMBER [app-todo-dev-norwayeast];

// Outputs
// ============================================================================

@description('Resource ID of the App Service Plan.')
output appServicePlanResourceId string = appServicePlan.outputs.resourceId

@description('Resource ID of the Web App.')
output appServiceResourceId string = webApp.outputs.resourceId

@description('Name of the Web App.')
output appServiceName string = webApp.outputs.name

@description('Default hostname of the Web App.')
output appServiceDefaultHostname string = webApp.outputs.defaultHostname

@description('Principal ID of the Web App Managed Identity.')
output appServicePrincipalId string = webApp.outputs.systemAssignedMIPrincipalId
