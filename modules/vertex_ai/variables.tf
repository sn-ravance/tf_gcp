variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "network" {
  description = "The self_link of the VPC network"
  type        = string
}

variable "subnet" {
  description = "The self_link of the subnet"
  type        = string
}

variable "service_account" {
  description = "Service account email for the Workbench instance"
  type        = string
}
