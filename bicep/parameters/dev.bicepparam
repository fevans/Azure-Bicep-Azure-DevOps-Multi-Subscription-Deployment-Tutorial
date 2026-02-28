// ============================================================
// dev.bicepparam – Development environment parameters
// ============================================================
// Target subscription: DEV_SUBSCRIPTION_ID
// Service connection:  dev-service-connection
// Approvals required:  None (auto-deploys on every push to main)
// ============================================================

using '../main.bicep'

// Core identity
param appName = 'tutorial'
param environment = 'dev'
param location = 'eastus'

// Storage – cheapest redundancy for dev
param storageSkuName = 'Standard_LRS'

// App Service – Basic tier; cost-effective for dev workloads
param appServicePlanSkuName = 'B1'
param appServicePlanSkuTier = 'Basic'

// Replace with the Object ID of the DevOps service principal or your own
// Azure AD Object ID so the pipeline can manage Key Vault secrets.
// Retrieve it with: az ad sp show --id <clientId> --query id -o tsv
param keyVaultAdminObjectId = '00000000-0000-0000-0000-000000000000'
