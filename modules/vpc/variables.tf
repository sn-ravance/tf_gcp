variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "secure-vpc"
}

variable "subnet_name" {
  description = "Name of the private subnet"
  type        = string
  default     = "private-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range for the private subnet"
  type        = string
  default     = "10.10.0.0/16"
}
