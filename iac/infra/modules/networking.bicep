// ============================================================================
// Module: networking.bicep
// Description: VNet, Subnets, and Network Security Groups
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

var nsgAppName = 'nsg-app-${environment}-${location}'
var nsgPeName = 'nsg-pe-${environment}-${location}'
var vnetName = 'vnet-${workload}-${environment}-${location}'
var snetAppName = 'snet-app-${environment}-${location}'
var snetPeName = 'snet-pe-${environment}-${location}'

// Resources
// ============================================================================

// NSG for App Service subnet
module nsgApp 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${nsgAppName}-deployment'
  params: {
    name: nsgAppName
    location: location
    tags: tags
    securityRules: [
      // Inbound rules
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      // Outbound rules
      {
        name: 'AllowSqlOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '1433'
        }
      }
      {
        name: 'AllowHttpsOutbound'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowAzureMonitorOutbound'
        properties: {
          priority: 210
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureMonitor'
          destinationPortRange: '443'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          priority: 4096
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// NSG for Private Endpoint subnet
module nsgPe 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${nsgPeName}-deployment'
  params: {
    name: nsgPeName
    location: location
    tags: tags
    securityRules: [
      // Inbound rules
      {
        name: 'AllowSqlFromAppSubnet'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.0.1.0/24'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '1433'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      // Outbound rules
      {
        name: 'DenyAllOutbound'
        properties: {
          priority: 4096
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// Virtual Network with subnets
module virtualNetwork 'br/public:avm/res/network/virtual-network:0.5.2' = {
  name: '${vnetName}-deployment'
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: [
      {
        name: snetAppName
        addressPrefix: '10.0.1.0/24'
        networkSecurityGroupResourceId: nsgApp.outputs.resourceId
        delegation: 'Microsoft.Web/serverFarms'
      }
      {
        name: snetPeName
        addressPrefix: '10.0.2.0/24'
        networkSecurityGroupResourceId: nsgPe.outputs.resourceId
      }
    ]
  }
}

// Outputs
// ============================================================================

@description('Resource ID of the Virtual Network.')
output vnetResourceId string = virtualNetwork.outputs.resourceId

@description('Name of the Virtual Network.')
output vnetName string = virtualNetwork.outputs.name

@description('Resource ID of the App Service subnet.')
output subnetAppResourceId string = virtualNetwork.outputs.subnetResourceIds[0]

@description('Resource ID of the Private Endpoint subnet.')
output subnetPeResourceId string = virtualNetwork.outputs.subnetResourceIds[1]

@description('Resource ID of the App NSG.')
output nsgAppResourceId string = nsgApp.outputs.resourceId

@description('Resource ID of the PE NSG.')
output nsgPeResourceId string = nsgPe.outputs.resourceId
