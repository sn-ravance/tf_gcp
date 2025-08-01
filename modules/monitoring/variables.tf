variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "uptime_check_config" {
  description = "Configuration for uptime checks"
  type        = any
  default     = {}
}

variable "alert_policies" {
  description = "List of alert policy configurations"
  type        = list(any)
  default     = []
}

variable "dashboards" {
  description = "List of dashboard configurations"
  type        = list(any)
  default     = []
}
