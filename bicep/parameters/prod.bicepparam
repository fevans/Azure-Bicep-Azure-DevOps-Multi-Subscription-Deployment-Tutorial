// ============================================================
// prod.bicepparam – Production environment parameters
// ============================================================
// Target subscription: PROD_SUBSCRIPTION_ID
// Service connection:  prod-service-connection
// Approvals required:  Yes – configure in the "production" Azure DevOps
//                      Environment under Pipelines > Environments
//                      Consider adding a business-hours deployment window.
// ============================================================

using '../main.bicep'

// Core identity
param appName = 'tutorial'
param environment = 'prod'
param location = 'eastus'

// Storage – zone-redundant for maximum intra-region durability
param storageSkuName = 'Standard_ZRS'

// App Service – PremiumV3 tier for production (better CPU/RAM,
// zone-redundancy option, enhanced networking)
param appServicePlanSkuName = 'P1v3'
param appServicePlanSkuTier = 'PremiumV3'

// Replace with the Object ID of the production DevOps service principal.
// Retrieve it with: az ad sp show --id <clientId> --query id -o tsv
param keyVaultAdminObjectId = '00000000-0000-0000-0000-000000000000'
