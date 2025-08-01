variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "billing_account" {
  description = "The GCP billing account ID"
  type        = string
}

variable "org_id" {
  description = "The GCP organization ID"
  type        = string
}

variable "folder_id" {
  description = "The GCP folder ID"
  type        = string
}

variable "team" {
  description = "Team label for resources"
  type        = string
}

variable "group_email" {
  description = "Email address of the viewer group"
  type        = string
}

variable "image_bucket" {
  description = "Name of the image storage bucket"
  type        = string
}

variable "image_bucket_location" {
  description = "Location for storage buckets"
  type        = string
}

variable "cmek" {
  description = "Customer-managed encryption key (CMEK) resource ID"
  type        = string
  default     = ""
}

variable "custom_service_account_email" {
  description = "Email of the custom service account"
  type        = string
}

variable "iam_sql_user" {
  description = "IAM user for Cloud SQL (e.g., user@domain.com)"
  type        = string
}
