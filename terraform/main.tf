terraform {
  # SECURITY FIX: Added remote state backend for team collaboration and state management
  # In production, use Azure Storage Account with appropriate access controls
  # Example:
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateaccountpg"
    container_name       = "tfstate"
    key                  = "hpngpg.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0" # Pin major version for stability
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${var.app_name}-${var.environment}"
  location = var.location
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.app_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30 # Increased from 7 to 30 for better compliance and debugging
}

resource "azurerm_container_registry" "main" {
  name                = "acr${var.app_name}${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  # SECURITY FIX: Disable admin account - use Azure RBAC or managed identity instead
  # Admin accounts are a security risk as they provide username/password access
  admin_enabled = false
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.app_name}-${var.environment}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_container_app" "api" {
  name                         = "ca-${var.app_name}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/${var.app_name}-api:${var.image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = var.environment == "prod" ? "Production" : "Development"
      }

      # SECURITY FIX: Secrets should come from Azure Key Vault, not be hardcoded
      # In production, use azurerm_key_vault_secret resources and reference them here
      # Example: secret_name = "database-connection-string"
      env {
        name        = "ConnectionStrings__Database"
        secret_name = "database-connection-string"
      }

      env {
        name        = "API_KEY"
        secret_name = "api-key"
      }

      env {
        name        = "DATADOG_API_KEY"
        secret_name = "datadog-api-key"
      }
    }

    min_replicas = 0
    max_replicas = 1
  }

  ingress {
    target_port      = 8080
    transport        = "http"
    external_enabled = true

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # SECURITY FIX: Use managed identity for ACR pull instead of admin credentials
  # This requires creating a User Assigned Managed Identity and granting it AcrPull role
  # For now, commented out - requires identity setup
  # identity {
  #   type = "UserAssigned"
  #   identity_ids = [azurerm_user_assigned_identity.main.id]
  # }

  secret {
    name = "database-connection-string"
    # In production, retrieve from Azure Key Vault or pipeline variables
    # For now, using variable as placeholder - should be replaced with Key Vault reference
    value = var.sql_connection_string
  }

  secret {
    name  = "api-key"
    value = var.api_key
  }

  secret {
    name  = "datadog-api-key"
    value = var.datadog_api_key
  }
}

output "app_url" {
  value = azurerm_container_app.api.ingress[0].fqdn
}

# SECURITY FIX: Removed acr_admin_password output - never expose secrets in outputs
