output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "subnet_id" {
  description = "The ID of the private subnet"
  value       = google_compute_subnetwork.private_subnet.id
}

output "subnet_self_link" {
  description = "The self_link of the private subnet"
  value       = google_compute_subnetwork.private_subnet.self_link
}

output "vpc_self_link" {
  description = "The self_link of the VPC"
  value       = google_compute_network.vpc.self_link
}
