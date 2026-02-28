targetScope = 'subscription'

param location string
param hubSubId string
param spokeSubId string

var hubRgName = 'rg-hub-network'
var spokeRgName = 'rg-spoke-network'

module hubRg '../modules/resourceGroup.bicep' = {
  scope: subscription(hubSubId)
  params: {
    rgName: hubRgName
    location: location
  }
}

module spokeRg '../modules/resourceGroup.bicep' = {
  scope: subscription(spokeSubId)
  params: {
    rgName: spokeRgName
    location: location
  }
}

module hubVnet '../modules/vnet.bicep' = {
  scope: resourceGroup(hubSubId, hubRgName)
  params: {
    vnetName: 'vnet-hub'
    location: location
  }
  dependsOn: [
    hubRg
  ]
}

module spokeVnet '../modules/vnet.bicep' = {
  scope: resourceGroup(spokeSubId, spokeRgName)
  params: {
    vnetName: 'vnet-spoke'
    location: location
  }
  dependsOn: [
    spokeRg
  ]
}
