// ============================================================================
// Module: database.bicep
// Description: SQL Server, SQL Database, Private DNS Zone, Private Endpoint
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

@description('Object ID of the Entra ID administrator for SQL Server.')
param sqlAdminObjectId string

@description('Display name of the Entra ID administrator for SQL Server.')
param sqlAdminLoginName string = 'sqladmin-entra'

@description('Resource ID of the Private Endpoint subnet.')
param subnetPeResourceId string

@description('Resource ID of the Virtual Network for DNS zone linking.')
param vnetResourceId string

// Variables
// ============================================================================

var sqlServerName = 'sql-${workload}-${environment}-${location}'
var sqlDatabaseName = 'sqldb-${workload}-${environment}-${location}'
var privateEndpointName = 'pep-sql-${environment}-${location}'

#disable-next-line no-hardcoded-env-urls
var privateDnsZoneName = 'privatelink.database.windows.net'

// Resources
// ============================================================================

// SQL Server with Azure AD-only authentication
module sqlServer 'br/public:avm/res/sql/server:0.12.0' = {
  name: '${sqlServerName}-deployment'
  params: {
    name: sqlServerName
    location: location
    tags: tags
    administratorLogin: ''
    administratorLoginPassword: ''
    administrators: {
      azureADOnlyAuthentication: true
      login: sqlAdminLoginName
      principalType: 'Group'
      sid: sqlAdminObjectId
      tenantId: tenant().tenantId
    }
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: '1.2'
    databases: [
      {
        name: sqlDatabaseName
        sku: {
          name: 'Basic'
          tier: 'Basic'
          capacity: 5
        }
        maxSizeBytes: 2147483648 // 2 GB
      }
    ]
  }
}

// Private DNS Zone for SQL
module privateDnsZone 'br/public:avm/res/network/private-dns-zone:0.7.1' = {
  name: '${replace(privateDnsZoneName, '.', '-')}-deployment'
  params: {
    name: privateDnsZoneName
    tags: tags
    virtualNetworkLinks: [
      {
        virtualNetworkResourceId: vnetResourceId
        registrationEnabled: false
      }
    ]
  }
}

// Private Endpoint for SQL Server
module privateEndpoint 'br/public:avm/res/network/private-endpoint:0.10.1' = {
  name: '${privateEndpointName}-deployment'
  params: {
    name: privateEndpointName
    location: location
    tags: tags
    subnetResourceId: subnetPeResourceId
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: sqlServer.outputs.resourceId
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
    privateDnsZoneGroup: {
      privateDnsZoneGroupConfigs: [
        {
          privateDnsZoneResourceId: privateDnsZone.outputs.resourceId
        }
      ]
    }
  }
}

// Outputs
// ============================================================================

@description('Resource ID of the SQL Server.')
output sqlServerResourceId string = sqlServer.outputs.resourceId

@description('Fully qualified domain name of the SQL Server.')
output sqlServerFqdn string = sqlServer.outputs.fullyQualifiedDomainName

@description('Name of the SQL Server.')
output sqlServerName string = sqlServer.outputs.name

@description('Name of the SQL Database.')
output sqlDatabaseName string = sqlDatabaseName

@description('Resource ID of the SQL Database.')
output sqlDatabaseResourceId string = '${sqlServer.outputs.resourceId}/databases/${sqlDatabaseName}'

@description('Resource ID of the Private Endpoint.')
output privateEndpointResourceId string = privateEndpoint.outputs.resourceId

@description('Resource ID of the Private DNS Zone.')
output privateDnsZoneResourceId string = privateDnsZone.outputs.resourceId
