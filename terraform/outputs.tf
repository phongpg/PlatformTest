output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_admin_username" {
  value = azurerm_container_registry.main.admin_username
}

output "acr_admin_password" {
  value = azurerm_container_registry.main.admin_password
}

output "container_app_url" {
  value = "https://${azurerm_container_app.api.ingress[0].fqdn}"
}
