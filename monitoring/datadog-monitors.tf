terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"  # Pin major version for stability
    }
  }
}

# SECURITY FIX: Datadog credentials should come from environment variables or secure store
# Never hardcode API keys in Terraform files
# Set DD_API_KEY and DD_APP_KEY as environment variables or use Terraform variables
provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.com/"
}

variable "datadog_api_key" {
  description = "Datadog API key (should come from environment or secure store)"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog App key (should come from environment or secure store)"
  type        = string
  sensitive   = true
}

variable "app_name" {
  description = "Application name for monitor naming"
  type        = string
  default     = "myapp"
}

resource "datadog_monitor" "cpu_high" {
  name    = "High CPU - ${var.app_name}"
  type    = "metric alert"
  message = "CPU usage is critically high for {{container_app_name}}. Investigate immediately."

  # OPERATIONAL FIX: Increased threshold from 50% to 80% to reduce alert fatigue
  # Added 5m evaluation window to avoid transient spikes
  query = "avg(last_5m):avg:azure.containerapp.cpu_usage{container_app_name:ca-${var.app_name}-api} > 80"

  monitor_thresholds {
    critical = 80
    warning  = 70
  }

  # Require sustained high CPU for 5 minutes before alerting
  evaluation_delay = 300
  notify_no_data   = false
}

resource "datadog_monitor" "response_time" {
  name    = "Slow Response Time - ${var.app_name}"
  type    = "metric alert"
  message = "Response time is degraded for {{service.name}}. Check performance."

  # OPERATIONAL FIX: Increased threshold and evaluation window to reduce noise
  query = "avg(last_5m):avg:trace.http.request.duration{service:${var.app_name}-api} > 1.0"

  monitor_thresholds {
    critical = 1.0
    warning  = 0.5
  }

  evaluation_delay = 300
  notify_no_data   = false
}

resource "datadog_monitor" "error_log" {
  name    = "High Error Rate - ${var.app_name}"
  type    = "log alert"
  message = "High error rate detected for {{service.name}}. Investigate immediately."

  # OPERATIONAL FIX: Changed from > 0 to > 10 to avoid alerting on single errors
  # Added 5m window and proper log query
  query = "logs(\"status:error service:${var.app_name}-api\").index(\"*\").rollup(\"count\").last(\"5m\") > 10"

  monitor_thresholds {
    critical = 10
    warning  = 5
  }

  evaluation_delay = 300
  notify_no_data   = false
}

resource "datadog_monitor" "container_running" {
  name    = "Container Down - ${var.app_name}"
  type    = "service check"
  message = "Container is down for {{container_app_name}}. Immediate action required."

  query = "\"process.up\".over(\"container_app_name:ca-${var.app_name}-api\").last(1).count_by_status()"

  monitor_thresholds {
    critical = 0
  }

  evaluation_delay = 60
  notify_no_data   = true
}

# ADDITION: Memory monitoring - critical for container health
resource "datadog_monitor" "memory_high" {
  name    = "High Memory Usage - ${var.app_name}"
  type    = "metric alert"
  message = "Memory usage is critically high for {{container_app_name}}. Investigate potential memory leaks."

  query = "avg(last_5m):avg:azure.containerapp.memory_usage{container_app_name:ca-${var.app_name}-api} > 3500000000"

  monitor_thresholds {
    critical = 3500000000  # ~3.5GB (container has 4GB)
    warning  = 3000000000   # ~3GB
  }

  evaluation_delay = 300
  notify_no_data   = false
}

# ADDITION: HTTP 5xx error rate monitoring - critical for production
resource "datadog_monitor" "http_5xx_errors" {
  name    = "High 5xx Error Rate - ${var.app_name}"
  type    = "metric alert"
  message = "High 5xx error rate detected for {{service.name}}. Check application logs."

  query = "sum(last_5m):sum:trace.http.request.hits{service:${var.app_name}-api,status:5xx}.as_rate() > 10"

  monitor_thresholds {
    critical = 10
    warning  = 5
  }

  evaluation_delay = 300
  notify_no_data   = false
}

resource "datadog_dashboard" "app_dashboard" {
  title       = "${var.app_name} Dashboard"
  description = "Dashboard for ${var.app_name}"
  layout_type = "ordered"

  widget {
    timeseries_definition {
      title = "CPU Usage"
      request {
        q            = "avg:azure.containerapp.cpu_usage{container_app_name:ca-${var.app_name}-api}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Memory Usage"
      request {
        q            = "avg:azure.containerapp.memory_usage{container_app_name:ca-${var.app_name}-api}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Request Rate"
      request {
        q            = "sum:trace.http.request.hits{service:${var.app_name}-api}.as_rate()"
        display_type = "bars"
      }
    }
  }

  # ADDITION: Error rate widget
  widget {
    timeseries_definition {
      title = "Error Rate"
      request {
        q            = "sum:trace.http.request.hits{service:${var.app_name}-api,status:5xx}.as_rate()"
        display_type = "line"
      }
    }
  }
}
