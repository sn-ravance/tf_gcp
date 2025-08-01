variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "cmek" {
  description = "Customer-managed encryption key (CMEK) resource ID"
  type        = string
  default     = ""
}

variable "private_network" {
  description = "The self_link of the VPC network"
  type        = string
}

variable "iam_sql_user" {
  description = "IAM user for Cloud SQL (e.g., user@domain.com)"
  type        = string
}
