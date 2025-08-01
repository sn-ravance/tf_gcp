variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "bindings" {
  description = "IAM bindings in the form {role = [members]}"
  type        = map(list(string))
}

variable "service_accounts" {
  description = "List of service account emails to bind roles to"
  type        = list(string)
  default     = []
}
