// ============================================================
// main.bicep – Subscription-scoped orchestration template
// ============================================================
// Targets the *subscription* scope so that the resource group
// itself is created (or updated) as part of this deployment.
// Each environment's resource group, storage account, key vault,
// and app service are all managed from this single entry point.
// ============================================================

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Short name for the application. Used to build resource names.')
@minLength(2)
@maxLength(10)
param appName string

@description('Deployment environment (dev | staging | prod).')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Azure region for all resources.')
param location string = 'eastus'

@description('Storage account SKU.')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Premium_LRS'])
param storageSkuName string = 'Standard_LRS'

@description('App Service Plan SKU name (e.g. B1, S1, P1v3).')
param appServicePlanSkuName string = 'B1'

@description('App Service Plan SKU tier (e.g. Basic, Standard, PremiumV3).')
param appServicePlanSkuTier string = 'Basic'

@description('Object ID of the principal (user or managed identity) that will be granted Key Vault access.')
param keyVaultAdminObjectId string

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var resourceGroupName = 'rg-${appName}-${environment}'
var storageAccountName = 'st${appName}${environment}${uniqueString(subscription().subscriptionId, appName, environment)}'
var keyVaultName = 'kv-${appName}-${environment}-${uniqueString(subscription().subscriptionId, appName, environment)}'
var appServicePlanName = 'asp-${appName}-${environment}'
var webAppName = 'app-${appName}-${environment}-${uniqueString(subscription().subscriptionId, appName, environment)}'

var tags = {
  application: appName
  environment: environment
  managedBy: 'bicep'
  deployedBy: 'azure-devops'
}

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------

resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

module storage 'modules/storageAccount.bicep' = {
  name: 'deploy-storage-${environment}'
  scope: rg
  params: {
    storageAccountName: take(storageAccountName, 24)
    location: location
    skuName: storageSkuName
    tags: tags
  }
}

module keyVault 'modules/keyVault.bicep' = {
  name: 'deploy-keyvault-${environment}'
  scope: rg
  params: {
    keyVaultName: take(keyVaultName, 24)
    location: location
    tags: tags
    adminObjectId: keyVaultAdminObjectId
    storageAccountId: storage.outputs.storageAccountId
  }
}

module appService 'modules/appService.bicep' = {
  name: 'deploy-appservice-${environment}'
  scope: rg
  params: {
    appServicePlanName: appServicePlanName
    webAppName: take(webAppName, 60)
    location: location
    skuName: appServicePlanSkuName
    skuTier: appServicePlanSkuTier
    tags: tags
    keyVaultUri: keyVault.outputs.keyVaultUri
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output resourceGroupName string = rg.name
output storageAccountName string = storage.outputs.storageAccountName
output keyVaultName string = keyVault.outputs.keyVaultName
output webAppName string = appService.outputs.webAppName
output webAppHostname string = appService.outputs.webAppHostname
