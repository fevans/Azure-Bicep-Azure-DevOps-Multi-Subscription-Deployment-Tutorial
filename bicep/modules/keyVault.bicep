// ============================================================
// keyVault.bicep – Azure Key Vault module
// ============================================================
// Creates an Azure Key Vault with:
//   - RBAC authorization (preferred over access policies)
//   - Soft delete (7–90 days; 7 days for dev, 90 for prod)
//   - Purge protection enabled
//   - Diagnostic settings sending audit logs to Storage
// ============================================================

@description('Name of the Key Vault (3–24 alphanumeric and hyphens).')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Azure region for the Key Vault.')
param location string

@description('Resource tags.')
param tags object = {}

@description('Object ID of the principal to assign the Key Vault Administrator role.')
param adminObjectId string

@description('Resource ID of the storage account used for diagnostic logs.')
param storageAccountId string

@description('Number of days to retain soft-deleted secrets/keys (7–90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Grant the admin principal the "Key Vault Administrator" role
var keyVaultAdministratorRoleId = '00482a5a-887f-4fb3-b363-3b7fe8e74483'
resource adminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, adminObjectId, keyVaultAdministratorRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultAdministratorRoleId)
    principalId: adminObjectId
    principalType: 'ServicePrincipal'
  }
}

// Send Key Vault audit logs to the Storage Account
resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${keyVaultName}'
  scope: keyVault
  properties: {
    storageAccountId: storageAccountId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 90
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 30
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
