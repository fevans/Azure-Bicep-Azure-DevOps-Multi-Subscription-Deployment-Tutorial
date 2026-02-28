// ============================================================
// appService.bicep – Azure App Service Plan + Web App module
// ============================================================
// Creates:
//   - App Service Plan (Linux)
//   - Web App configured with:
//       • System-assigned managed identity
//       • HTTPS-only
//       • TLS 1.2 minimum
//       • Key Vault reference app setting
//       • Detailed error logging enabled
// ============================================================

@description('Name of the App Service Plan.')
param appServicePlanName string

@description('Name of the Web App (globally unique).')
@minLength(2)
@maxLength(60)
param webAppName string

@description('Azure region for both resources.')
param location string

@description('App Service Plan SKU name (e.g. B1, S1, P1v3).')
param skuName string = 'B1'

@description('App Service Plan SKU tier (e.g. Basic, Standard, PremiumV3).')
param skuTier string = 'Basic'

@description('Resource tags.')
param tags object = {}

@description('URI of the Key Vault to reference in app settings.')
param keyVaultUri string

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  kind: 'linux'
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      http20Enabled: true
      alwaysOn: skuTier != 'Free' && skuTier != 'Shared'
      appSettings: [
        {
          name: 'KEY_VAULT_URI'
          value: keyVaultUri
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
      detailedErrorLoggingEnabled: true
      httpLoggingEnabled: true
      requestTracingEnabled: true
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output appServicePlanId string = appServicePlan.id
output webAppId string = webApp.id
output webAppName string = webApp.name
output webAppHostname string = webApp.properties.defaultHostName
output webAppPrincipalId string = webApp.identity.principalId
