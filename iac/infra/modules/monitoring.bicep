// ============================================================================
// Module: monitoring.bicep
// Description: Log Analytics Workspace and Application Insights
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

// Variables
// ============================================================================

var lawName = 'law-${workload}-${environment}-${location}'
var appiName = 'appi-${workload}-${environment}-${location}'

// Resources
// ============================================================================

// Log Analytics Workspace
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.9.1' = {
  name: '${lawName}-deployment'
  params: {
    name: lawName
    location: location
    tags: tags
    skuName: 'PerGB2018'
  }
}

// Application Insights
module appInsights 'br/public:avm/res/insights/component:0.4.2' = {
  name: '${appiName}-deployment'
  params: {
    name: appiName
    location: location
    tags: tags
    workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    kind: 'web'
  }
}

// Outputs
// ============================================================================

@description('Resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.resourceId

@description('Name of the Log Analytics Workspace.')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.outputs.name

@description('Resource ID of Application Insights.')
output appInsightsResourceId string = appInsights.outputs.resourceId

@description('Application Insights instrumentation key.')
output appInsightsInstrumentationKey string = appInsights.outputs.instrumentationKey

@description('Application Insights connection string.')
output appInsightsConnectionString string = appInsights.outputs.connectionString
