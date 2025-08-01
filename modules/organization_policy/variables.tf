variable "org_id" {
  description = "The GCP organization ID"
  type        = string
}

variable "policy_constraints" {
  description = "Map of constraint names to enforcement (true/false)"
  type        = map(bool)
}
