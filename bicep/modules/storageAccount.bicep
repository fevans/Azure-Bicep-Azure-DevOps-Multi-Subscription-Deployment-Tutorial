// ============================================================
// storageAccount.bicep – Azure Storage Account module
// ============================================================
// Creates a Storage Account with secure-by-default settings:
//   - HTTPS-only access
//   - TLS 1.2 minimum
//   - Public blob access disabled
//   - Azure AD authentication required (shared key disabled)
// ============================================================

@description('Name of the Storage Account (lowercase alphanumeric, max 24 chars).')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Azure region for the Storage Account.')
param location string

@description('Storage Account SKU.')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Premium_LRS'])
param skuName string = 'Standard_LRS'

@description('Resource tags.')
param tags object = {}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
