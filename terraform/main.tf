terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "rg-myapp-prod"
  location = "West US"
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-myapp-prod"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 7
}

resource "azurerm_container_registry" "main" {
  name                = "acrmyappprod"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-myapp-prod"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

resource "azurerm_container_app" "api" {
  name                         = "ca-myapp-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  template {
    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/myapp-api:${var.image_tag}"
      cpu    = 2.0
      memory = "4Gi"

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }

      env {
        name  = "ConnectionStrings__Database"
        value = "Server=sql-myapp-prod.database.windows.net;Database=myapp;User Id=sqladmin;Password=P@ssw0rd123!;Encrypt=true"
      }

      env {
        name  = "API_KEY"
        value = "sk-proj-abc123def456ghi789"
      }

      env {
        name  = "DATADOG_API_KEY"
        value = "dd-api-1234567890abcdef"
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

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }
}

output "app_url" {
  value = azurerm_container_app.api.ingress[0].fqdn
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "acr_admin_password" {
  value = azurerm_container_registry.main.admin_password
}
