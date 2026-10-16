terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

provider "datadog" {
  api_key = "dd-api-1234567890abcdef"
  app_key = "dd-app-key-abcdef123456"
  api_url = "https://api.datadoghq.com/"
}

resource "datadog_monitor" "cpu_high" {
  name    = "High CPU"
  type    = "metric alert"
  message = "CPU is high. Check the app."

  query = "avg(last_1m):avg:azure.containerapp.cpu_usage{container_app_name:ca-myapp-api} > 50"

  monitor_thresholds {
    critical = 50
  }
}

resource "datadog_monitor" "response_time" {
  name    = "Slow Response"
  type    = "metric alert"
  message = "Response time is slow."

  query = "avg(last_1m):avg:trace.http.request.duration{service:myapp-api} > 0.5"

  monitor_thresholds {
    critical = 0.5
  }
}

resource "datadog_monitor" "error_log" {
  name    = "Errors in Logs"
  type    = "log alert"
  message = "There are errors in the logs."

  query = "logs(\"status:error\").index(\"*\").rollup(\"count\").last(\"5m\") > 0"

  monitor_thresholds {
    critical = 0
  }
}

resource "datadog_monitor" "container_running" {
  name    = "Container Running"
  type    = "service check"
  message = "Container might be down."

  query = "\"process.up\".over(\"container_app_name:ca-myapp-api\").last(1).count_by_status()"

  monitor_thresholds {
    critical = 1
  }
}

resource "datadog_dashboard" "app_dashboard" {
  title       = "My App Dashboard"
  description = "Dashboard for the app"
  layout_type = "ordered"

  widget {
    timeseries_definition {
      title = "CPU"
      request {
        q            = "avg:azure.containerapp.cpu_usage{*}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Memory"
      request {
        q            = "avg:azure.containerapp.memory_usage{*}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Requests"
      request {
        q            = "sum:trace.http.request.hits{service:myapp-api}.as_count()"
        display_type = "bars"
      }
    }
  }
}
