# Azure Bicep × Azure DevOps — Multi-Subscription Deployment Tutorial

A production-style, end-to-end tutorial demonstrating how to deploy Azure Bicep infrastructure **across multiple subscriptions** using an Azure DevOps multi-stage pipeline with **artifact promotion**.

---

## What This Tutorial Demonstrates

| Concept | Where |
|---|---|
| Bicep at subscription scope (create resource group + resources in one template) | `bicep/main.bicep` |
| Modular Bicep design (Storage, Key Vault, App Service) | `bicep/modules/` |
| Per-environment `.bicepparam` files | `bicep/parameters/` |
| Multi-stage Azure DevOps pipeline (Build → Dev → Staging → Prod) | `azure-pipelines.yml` |
| **Artifact promotion** – build once, deploy the same artifact everywhere | Build stage publishes; each deploy stage downloads |
| Multi-subscription deployment via separate service connections | `dev-`, `staging-`, `prod-service-connection` |
| What-if previews before every deployment | `az deployment sub what-if` in Staging & Prod stages |
| Approval gates between environments | Azure DevOps Environments |

---

## Repository Structure

```
.
├── azure-pipelines.yml          # Multi-stage Azure DevOps pipeline
└── bicep/
    ├── main.bicep               # Subscription-scoped entry point
    ├── modules/
    │   ├── storageAccount.bicep # Azure Storage Account
    │   ├── keyVault.bicep       # Azure Key Vault (RBAC + diagnostics)
    │   └── appService.bicep     # App Service Plan + Web App
    └── parameters/
        ├── dev.bicepparam       # Dev environment values
        ├── staging.bicepparam   # Staging environment values
        └── prod.bicepparam      # Production environment values
```

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Azure DevOps Pipeline                                           │
│                                                                  │
│  ┌─────────┐    ┌───────────┐    ┌───────────┐    ┌──────────┐  │
│  │  Build  │───▶│  Dev      │───▶│  Staging  │───▶│  Prod    │  │
│  │  Stage  │    │  Stage    │    │  Stage    │    │  Stage   │  │
│  │         │    │           │    │           │    │          │  │
│  │Validate │    │Auto-deploy│    │  Approval │    │ Approval │  │
│  │& Publish│    │to Dev Sub │    │  required │    │ required │  │
│  │Artifact │    │           │    │to Stg Sub │    │to Prd Sub│  │
│  └─────────┘    └───────────┘    └───────────┘    └──────────┘  │
│       │               │                │                │        │
│       ▼               ▼                ▼                ▼        │
│  [bicep-templates artifact — same artifact used in all stages]   │
└──────────────────────────────────────────────────────────────────┘

Each subscription gets:
  rg-tutorial-<env>/
    ├── sttutorial<env><unique>    (Storage Account)
    ├── kv-tutorial-<env>-<unique> (Key Vault)
    ├── asp-tutorial-<env>         (App Service Plan)
    └── app-tutorial-<env>-<unique>(Web App)
```

### Key Point – Artifact Promotion

The **Build** stage validates all Bicep templates against the Dev subscription and publishes the `bicep/` directory as a pipeline artifact named `bicep-templates`. Every downstream stage (`DeployDev`, `DeployStaging`, `DeployProd`) downloads this **exact same artifact** and deploys it with environment-specific parameter files.

This guarantees that:
1. The templates running in Production are the **identical files** that passed validation and Dev deployment.
2. No ad-hoc edits can sneak in between environments.
3. A failed deployment in any stage blocks promotion to the next.

---

## Prerequisites

### Azure

- Three Azure subscriptions: **Dev**, **Staging**, **Production**.
- An Azure AD service principal (or Managed Identity) per subscription with **Contributor** rights on that subscription.
  - Note the **Client ID** and **Object ID** of each principal — you will need them below.

### Azure DevOps

1. **Service connections** — one per subscription, of type *Azure Resource Manager* using the service principals above:

   | Name | Target Subscription |
   |---|---|
   | `dev-service-connection` | Dev |
   | `staging-service-connection` | Staging |
   | `prod-service-connection` | Production |

2. **Pipeline variables** — add these as secret pipeline variables (or a variable group):

   | Variable | Value |
   |---|---|
   | `DEV_SUBSCRIPTION_ID` | Dev subscription GUID |
   | `STAGING_SUBSCRIPTION_ID` | Staging subscription GUID |
   | `PROD_SUBSCRIPTION_ID` | Production subscription GUID |

3. **Environments** — create three environments under **Pipelines → Environments**:

   | Name | Recommended checks |
   |---|---|
   | `development` | None (auto-deploy) |
   | `staging` | Required reviewer approval |
   | `production` | Required reviewer approval + business-hours deployment window |

---

## Setup Steps

### 1 — Fork & Clone

```bash
git clone https://github.com/<your-org>/Azure-Bicep-Azure-DevOps-Multi-Subscription-Deployment-Tutorial.git
cd Azure-Bicep-Azure-DevOps-Multi-Subscription-Deployment-Tutorial
```

### 2 — Update Parameter Files

Open each `bicep/parameters/*.bicepparam` file and replace the placeholder `keyVaultAdminObjectId` with the **Object ID** of the respective service principal.

To find the Object ID of a service principal by its Client ID:

```bash
az ad sp show --id <CLIENT_ID> --query id -o tsv
```

### 3 — Create the Pipeline in Azure DevOps

1. Navigate to **Pipelines → New pipeline**.
2. Select **Azure Repos Git** (or GitHub, depending on where you forked).
3. Select **Existing Azure Pipelines YAML file**.
4. Choose `azure-pipelines.yml` and click **Continue → Save**.

### 4 — Configure Service Connections

1. Go to **Project Settings → Service connections → New service connection**.
2. Choose **Azure Resource Manager → Service principal (manual)** and fill in the details for Dev, Staging, and Production.
3. Name them exactly as listed in the table above.

### 5 — Add Pipeline Variables

1. Edit the pipeline and click **Variables**.
2. Add `DEV_SUBSCRIPTION_ID`, `STAGING_SUBSCRIPTION_ID`, and `PROD_SUBSCRIPTION_ID` as **secret** variables.

### 6 — Set Up Environment Approvals

1. Go to **Pipelines → Environments**.
2. Open the `staging` environment → **Approvals and checks → Approvals** → add yourself or a reviewer.
3. Repeat for `production`, optionally adding a **Business Hours** check.

### 7 — Run the Pipeline

Push any change to `main` (or trigger manually) to start:

```
Build ──▶ Dev (auto) ──▶ Staging (approval) ──▶ Production (approval)
```

---

## Bicep Templates in Detail

### `main.bicep` — Subscription Scope

Deploying at `targetScope = 'subscription'` lets a **single** `az deployment sub create` call create the resource group *and* all resources inside it. No need to pre-create the resource group or use a separate deployment.

### `modules/storageAccount.bicep`

- `StorageV2`, `Hot` tier
- HTTPS-only, TLS 1.2
- Public blob access **disabled**
- Shared key access **disabled** (Azure AD auth only)
- Network default action `Deny` (Azure services bypass)

### `modules/keyVault.bicep`

- RBAC authorization (not legacy access policies)
- Soft delete enabled, purge protection enabled
- Admin role assignment via `Key Vault Administrator` built-in role
- Diagnostic logs streamed to the Storage Account

### `modules/appService.bicep`

- Linux App Service Plan
- System-assigned managed identity (use this identity to access Key Vault secrets)
- HTTPS-only, TLS 1.2, FTP disabled
- `KEY_VAULT_URI` app setting wired in automatically

---

## Pipeline Stages in Detail

### Stage 1 – Build & Validate

```
1. az bicep install          (ensure latest Bicep CLI)
2. az bicep build            (transpile every .bicep → ARM JSON; catches syntax errors)
3. az deployment sub what-if (dry-run against Dev subscription; catches semantic errors)
4. publish artifact          (upload bicep/ directory as 'bicep-templates')
```

### Stage 2 – Deploy Dev

```
1. download artifact 'bicep-templates'
2. az deployment sub create  (deploy to Dev subscription with dev.bicepparam)
```

### Stage 3 – Deploy Staging *(approval required)*

```
1. download artifact 'bicep-templates'   ← same artifact as Dev
2. az deployment sub what-if             (show reviewer what will change)
3. az deployment sub create              (deploy to Staging subscription with staging.bicepparam)
```

### Stage 4 – Deploy Production *(approval required, main branch only)*

```
1. download artifact 'bicep-templates'   ← same artifact as Dev & Staging
2. az deployment sub what-if             (show reviewer what will change)
3. az deployment sub create              (deploy to Production subscription with prod.bicepparam)
```

---

## Environment Differences

| Setting | Dev | Staging | Production |
|---|---|---|---|
| Storage SKU | `Standard_LRS` | `Standard_GRS` | `Standard_ZRS` |
| App Service Plan | B1 (Basic) | S1 (Standard) | P1v3 (PremiumV3) |
| Deployment approval | None | Required | Required |
| Key Vault soft-delete days | 90 | 90 | 90 |

---

## Cleanup

To remove all resources created by this tutorial:

```bash
# Dev
az group delete --name rg-tutorial-dev --subscription <DEV_SUBSCRIPTION_ID> --yes --no-wait

# Staging
az group delete --name rg-tutorial-staging --subscription <STAGING_SUBSCRIPTION_ID> --yes --no-wait

# Production
az group delete --name rg-tutorial-prod --subscription <PROD_SUBSCRIPTION_ID> --yes --no-wait
```

> **Note:** Key Vaults with purge protection cannot be permanently deleted for the soft-delete retention period. Use `az keyvault purge` after the retention period expires if you need to reuse the same name.

---

## License

MIT
