// ============================================================================
// Module: alerts.bicep
// Description: Metric Alert Rules and Diagnostic Settings
//              Deployed after all resources are provisioned
// ============================================================================

// Parameters
// ============================================================================

@description('Environment name (dev, staging, prod).')
param environment string

@description('Workload name used in resource naming.')
param workload string

@description('Tags to apply to all resources.')
param tags object

@description('Resource ID of the Log Analytics Workspace.')
param logAnalyticsWorkspaceId string

@description('Resource ID of the App Service.')
param appServiceResourceId string

@description('Name of the App Service.')
param appServiceName string

@description('Resource ID of the SQL Database.')
param sqlDatabaseResourceId string

@description('Name of the SQL Server.')
param sqlServerName string

@description('Name of the SQL Database.')
param sqlDatabaseName string

// Existing Resource References
// ============================================================================

resource appService 'Microsoft.Web/sites@2023-12-01' existing = {
  name: appServiceName
}

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' existing = {
  name: sqlServerName
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' existing = {
  parent: sqlServer
  name: sqlDatabaseName
}

// Alert Rules — App Service
// ============================================================================

resource alertCpuHigh 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-cpu-high-${workload}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when App Service CPU exceeds 80%'
    severity: 2
    enabled: true
    scopes: [
      appServiceResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCPU'
          metricName: 'CpuPercentage'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

resource alertHttp5xx 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-http5xx-${workload}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when HTTP 5xx errors exceed 5 in 5 minutes'
    severity: 1
    enabled: true
    scopes: [
      appServiceResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xxErrors'
          metricName: 'Http5xx'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

resource alertResponseTime 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-response-time-${workload}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when response time exceeds 2 seconds'
    severity: 2
    enabled: true
    scopes: [
      appServiceResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighResponseTime'
          metricName: 'HttpResponseTime'
          operator: 'GreaterThan'
          threshold: 2
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

resource alertHealthCheck 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-health-check-${workload}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when health check status drops below 100%'
    severity: 1
    enabled: true
    scopes: [
      appServiceResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HealthCheckFailure'
          metricName: 'HealthCheckStatus'
          operator: 'LessThan'
          threshold: 100
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// Alert Rules — SQL Database
// ============================================================================

resource alertDtuHigh 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-dtu-high-${workload}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when SQL Database DTU exceeds 80%'
    severity: 2
    enabled: true
    scopes: [
      sqlDatabaseResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighDTU'
          metricName: 'dtu_consumption_percent'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

resource alertFailedConnections 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-failed-connections-${workload}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when failed connections exceed 10 in 5 minutes'
    severity: 1
    enabled: true
    scopes: [
      sqlDatabaseResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FailedConnections'
          metricName: 'connection_failed'
          operator: 'GreaterThan'
          threshold: 10
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

resource alertDeadlocks 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-deadlocks-${workload}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert on any deadlocks'
    severity: 2
    enabled: true
    scopes: [
      sqlDatabaseResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Deadlocks'
          metricName: 'deadlock'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

resource alertStorageHigh 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-storage-high-${workload}-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when SQL Database storage exceeds 80%'
    severity: 3
    enabled: true
    scopes: [
      sqlDatabaseResourceId
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighStorage'
          metricName: 'storage_percent'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Maximum'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// Diagnostic Settings
// ============================================================================

// App Service diagnostic settings
resource diagAppService 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-appservice-${workload}-${environment}'
  scope: appService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
  }
}

// SQL Server audit diagnostic settings
resource diagSqlServer 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-sqlserver-${workload}-${environment}'
  scope: sqlServer
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
      }
    ]
  }
}

// SQL Database diagnostic settings
resource diagSqlDatabase 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-sqldb-${workload}-${environment}'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLInsights'
        enabled: true
      }
      {
        category: 'AutomaticTuning'
        enabled: true
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled: true
      }
      {
        category: 'Errors'
        enabled: true
      }
      {
        category: 'Timeouts'
        enabled: true
      }
    ]
  }
}
