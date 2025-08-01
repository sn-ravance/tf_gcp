variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "service_accounts" {
  description = "List of service accounts to create (objects with name, display_name, description)"
  type = list(object({
    name         = string
    display_name = string
    description  = string
  }))
}

variable "iam_roles" {
  description = "Map of service account email to list of IAM roles"
  type        = map(list(string))
  default     = {}
}
