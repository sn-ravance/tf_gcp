variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "destination" {
  description = "Destination for the log sink (e.g., storage bucket, BigQuery dataset)"
  type        = string
}

variable "filter" {
  description = "Optional filter for logs"
  type        = string
  default     = ""
}

variable "include_children" {
  description = "Whether to include child resources"
  type        = bool
  default     = false
}

variable "sink_name" {
  description = "Name of the log sink"
  type        = string
}
