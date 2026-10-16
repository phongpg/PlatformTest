variable "environment" {
  description = "Environment name (nonprod, prod)"
  type        = string
  # SECURITY FIX: No default - must be explicitly set per environment
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West US"
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# SECURITY FIX: These secrets should come from Azure Key Vault or secure pipeline variables
# Never store secrets in .tfvars files committed to git
variable "sql_connection_string" {
  description = "Database connection string (should come from Key Vault)"
  type        = string
  sensitive   = true
}

variable "api_key" {
  description = "API key for external services (should come from Key Vault)"
  type        = string
  sensitive   = true
}

variable "datadog_api_key" {
  description = "Datadog API key (should come from Key Vault)"
  type        = string
  sensitive   = true
}
