// ============================================================
// staging.bicepparam – Staging environment parameters
// ============================================================
// Target subscription: STAGING_SUBSCRIPTION_ID
// Service connection:  staging-service-connection
// Approvals required:  Yes – configure in the "staging" Azure DevOps
//                      Environment under Pipelines > Environments
// ============================================================

using '../main.bicep'

// Core identity
param appName = 'tutorial'
param environment = 'staging'
param location = 'eastus'

// Storage – geo-redundant for staging to mirror production resiliency
param storageSkuName = 'Standard_GRS'

// App Service – Standard tier for staging (enables deployment slots,
// custom domains, auto-scale, etc.)
param appServicePlanSkuName = 'S1'
param appServicePlanSkuTier = 'Standard'

// Replace with the Object ID of the staging DevOps service principal.
// Retrieve it with: az ad sp show --id <clientId> --query id -o tsv
param keyVaultAdminObjectId = '00000000-0000-0000-0000-000000000000'
