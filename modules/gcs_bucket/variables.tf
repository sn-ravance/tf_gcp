variable "name" {
  description = "The name of the GCS bucket"
  type        = string
}

variable "location" {
  description = "The location for the bucket"
  type        = string
}

variable "cmek" {
  description = "CMEK key resource ID for encryption (optional)"
  type        = string
  default     = ""
}

variable "force_destroy" {
  description = "Whether to force destroy the bucket"
  type        = bool
  default     = false
}

variable "lifecycle_age" {
  description = "Age in days to delete objects (optional)"
  type        = number
  default     = 30
}

variable "labels" {
  description = "Labels to apply to the bucket"
  type        = map(string)
  default     = {}
}
