
output "organization_id" {
  description = "The ID of the GCP organization"
  value       = module.organization_policy.organization_id
}

output "folder_ids" {
  description = "List of folder IDs created or used"
  value       = module.organization_policy.folder_ids
}

output "policy_constraints" {
  description = "List of enforced organization policy constraints"
  value       = module.organization_policy.policy_constraints
}

output "project_ids" {
  description = "List of GCP project IDs created"
  value       = module.iam.project_ids
}

output "service_account_emails" {
  description = "List of service account emails created"
  value       = module.service_accounts.emails
}

output "viewer_group_binding" {
  description = "IAM binding for the viewer group"
  value       = module.iam.viewer_group_binding
}

output "vpc_names" {
  description = "List of VPC names created"
  value       = module.vpc.vpc_names
}

output "subnet_names" {
  description = "List of subnet names created"
  value       = module.vpc.subnet_names
}

output "psc_connections" {
  description = "Private Service Connect configurations"
  value       = module.vpc.psc_connections
}

output "firewall_rules" {
  description = "Firewall rules applied to the VPC"
  value       = module.vpc.firewall_rules
}

output "gcs_bucket_name" {
  description = "Name of the GCS bucket created for image corpus"
  value       = module.gcs_bucket.name
}

output "gcs_bucket_url" {
  description = "URL of the GCS bucket"
  value       = module.gcs_bucket.url
}

output "gcs_bucket_encryption" {
  description = "Encryption key used for the GCS bucket"
  value       = module.gcs_bucket.encryption_key
}

output "log_sink_names" {
  description = "List of log sink names created"
  value       = module.log_sinks.names
}

output "log_sink_destinations" {
  description = "List of log sink destinations"
  value       = module.log_sinks.destinations
}

output "monitoring_dashboards" {
  description = "List of monitoring dashboards created"
  value       = module.monitoring.dashboards
}

output "alert_policies" {
  description = "List of alert policies created"
  value       = module.monitoring.alert_policies
}

output "vertex_ai_region" {
  description = "Region where Vertex AI is deployed"
  value       = module.vertex_ai.region
}

output "vertex_ai_private_endpoint" {
  description = "Whether Vertex AI private endpoint is enabled"
  value       = module.vertex_ai.enable_private_endpoint
}

output "vertex_ai_rag_index" {
  description = "RAG index configuration for Vertex AI"
  value       = module.vertex_ai.rag_index
}

output "vertex_ai_workbench_instance" {
  description = "Workbench instance configuration"
  value       = module.vertex_ai.workbench_instance
}
