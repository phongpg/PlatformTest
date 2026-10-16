output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

# SECURITY FIX: Removed sensitive outputs (admin username/password)
# Never output secrets - they should be retrieved from Azure Key Vault or secure stores
# If needed for debugging, use terraform output with sensitive flag, but don't commit

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "container_app_url" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}
