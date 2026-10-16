# SECURITY FIX: Removed hardcoded secrets - these should come from Azure Key Vault
# or secure pipeline variables. In a real deployment, use:
# terraform apply -var="sql_connection_string=..." -var="api_key=..." -var="datadog_api_key=..."
# Or reference Key Vault secrets using azurerm_key_vault_secret data source

environment = "prod"
location    = "West US"
app_name    = "myapp"

# Placeholder values - DO NOT use these in production
# Replace with actual secret references or pass via secure pipeline variables
sql_connection_string = "Server=sql-myapp-prod.database.windows.net;Database=myapp;User Id=sqladmin;Password=CHANGE_ME;Encrypt=true"
api_key             = "CHANGE_ME"
datadog_api_key     = "CHANGE_ME"
