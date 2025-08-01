terraform {
  required_version = ">= 1.1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}



resource "google_project" "sandbox" {
  count           = 0
  project_id      = var.project_id
  name            = "Sandbox Project"
  billing_account = var.billing_account
  # org_id removed to avoid conflict; project will reside under folder only
  folder_id = var.folder_id
  labels = {
    env  = "sandbox"
    team = var.team
  }
}

resource "google_storage_bucket" "image_bucket" {
  name                        = var.image_bucket
  location                    = var.image_bucket_location
  uniform_bucket_level_access = true
  force_destroy               = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }


  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  dynamic "encryption" {
    for_each = var.cmek != "" ? [1] : []
    content {
      default_kms_key_name = var.cmek
    }
  }
}

resource "google_storage_bucket" "log_sink_bucket" {
  name                        = "${var.project_id}-log-sink"
  location                    = var.image_bucket_location
  uniform_bucket_level_access = true
  force_destroy               = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

}

# Remove the default network if it exists (CKV_GCP_27)
resource "google_compute_network" "default" {
  name    = "default"
  project = var.project_id

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [routing_mode]
  }
  provider = google
  # This will attempt to delete the default network if it exists.
  # If it does not exist this resource will be a no-op.
  # You may need to import the default network before destroy: 
  # terraform import google_compute_network.default projects/${var.project_id}/global/networks/default
  # Or manually delete it if import fails.
  count = 0 # Set to 1 and import if you want to destroy the default network.
}

# --- Organization Policy Constraints ---
resource "google_org_policy_policy" "disable_guest_attributes" {
  count  = 0
  name   = "organizations/${var.org_id}/policies/compute.disableGuestAttributesAccess"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = true
    }
  }
}

resource "google_org_policy_policy" "disable_sa_key_creation" {
  count  = 0
  name   = "organizations/${var.org_id}/policies/iam.disableServiceAccountKeyCreation"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = true
    }
  }
}

resource "google_org_policy_policy" "require_oslogin" {
  count  = 0
  name   = "organizations/${var.org_id}/policies/compute.requireOsLogin"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = true
    }
  }
}

# --- Secure VPC with Private Subnets and NAT ---
resource "google_compute_network" "secure_vpc" {
  name                    = "secure-vpc"
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "private_subnet" {
  name                     = "private-subnet"
  ip_cidr_range            = "10.10.0.0/16"
  region                   = var.region
  network                  = google_compute_network.secure_vpc.id
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = google_compute_network.secure_vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  count                              = 0
  name                               = "nat-config"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall: Allow IAP SSH only (tcp:22 from IAP ranges)
resource "google_compute_firewall" "iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.secure_vpc.id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"] # IAP TCP forwarding IP range
  direction     = "INGRESS"
  target_tags   = ["allow-iap-ssh"]
}

# --- Private Service Connection for Google-managed services ---
resource "google_compute_global_address" "services_psc" {
  name          = "services-psc"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.secure_vpc.id
}

resource "google_service_networking_connection" "services_vpc_connection" {
  network                 = google_compute_network.secure_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.services_psc.name]
}

# --- Centralized Log Sink to Storage Bucket ---
resource "google_logging_project_sink" "all_logs" {
  name        = "all-logs-to-bucket"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.log_sink_bucket.name}"
  filter      = "logName:*"

}

resource "google_storage_bucket_iam_member" "log_writer" {
  bucket     = google_storage_bucket.log_sink_bucket.name
  role       = "roles/storage.objectCreator"
  member     = "serviceAccount:service-874292933408@gcp-sa-logging.iam.gserviceaccount.com"
  depends_on = [google_project_service.enable_serviceusage]
}

# --- Secure Cloud SQL Instance (Postgres Private IP CMEK) ---
resource "google_sql_database_instance" "private_postgres" {
  depends_on = [
    google_service_networking_connection.services_vpc_connection
  ]
  name             = "private-postgres"
  region           = var.region
  database_version = "POSTGRES_15" # Use latest major version (CKV_GCP_79)
  project          = var.project_id

  settings {
    tier = "db-custom-1-3840"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.secure_vpc.id

    }
    backup_configuration {
      enabled = true
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_statement"
      value = "all"
    }
    database_flags {
      name  = "log_min_messages"
      value = "error"
    }
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "-1"
    }
    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }
  }











  deletion_protection = true
}

resource "google_sql_user" "iam_user" {
  name     = var.iam_sql_user
  instance = google_sql_database_instance.private_postgres.name
  type     = "CLOUD_IAM_USER"
}

# --- Vertex AI Workbench Instance (Private Endpoint) ---
# (commented out – provider v6 now uses google_workbench_instance)
/*
# resource "google_notebooks_instance" "private_workbench" {
  # name         = "private-workbench"
  # location     = var.region
  # project      = var.project_id
  # machine_type = "n1-standard-4"

  # vm_image {
  #   project      = "deeplearning-platform-release"
  #   image_family = "tf-latest-cpu"
  # }
  vm_image {
    project      = "deeplearning-platform-release"
    image_family = "tf-latest-cpu"
  }

  # boot_disk_type = "PD_STANDARD"
  # boot_disk_size_gb = 100

  network = google_compute_network.secure_vpc.id
  # subnet  = google_compute_subnetwork.private_subnet.id

  # no_public_ip = true
  service_account = var.custom_service_account_email
}

*/

# --- Vertex AI Index (RAG Example) ---
resource "google_vertex_ai_index" "rag_index" {
  count = 0

  region       = var.region
  project      = var.project_id
  display_name = "RAG Index"

}

module "services" {
  source     = "./modules/services"
  project_id = var.project_id
  services = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "notebooks.googleapis.com",
    "aiplatform.googleapis.com",
  ]
}

###############################################################################
# Organization-wide policy
###############################################################################
module "organization_policy" {
  count  = 0
  source = "./modules/organization_policy"

  org_id = var.org_id
  # list the org-policy constraint names you want enforced
  policy_constraints = {
    "compute.disableGuestAttributesAccess" = true
    "iam.disableServiceAccountKeyCreation" = true
    "compute.requireOsLogin"               = true
  }
}

###############################################################################
# IAM bindings (viewer group etc.)
###############################################################################
module "iam" {
  source = "./modules/iam"

  project_id = var.project_id

  # map of role → list of principals
  bindings = {
    "roles/viewer" = [
      "group:${var.group_email}",
    ]
  }
}

###############################################################################
# Service accounts for workloads / terraform
###############################################################################
module "service_accounts" {
  source     = "./modules/service_accounts"
  project_id = var.project_id

  service_accounts = [
    {
      name         = "custom-sa"
      display_name = "Custom Service Account"
      description  = "Service account for sandbox workloads"
    }
  ]

  # optional IAM role bindings for each SA
  iam_roles = {
    "custom-sa@${var.project_id}.iam.gserviceaccount.com" = [
      "roles/storage.objectAdmin",
      "roles/iam.serviceAccountTokenCreator",
    ]

  }
}

###############################################################################
# VPC & subnet
###############################################################################
module "vpc" {
  source = "./modules/vpc"

  project_id = var.project_id
  region     = var.region
}

###############################################################################
# Central image bucket (and optional log bucket)
###############################################################################
module "gcs_bucket" {
  source = "./modules/gcs_bucket"

  name     = var.image_bucket
  location = var.image_bucket_location
  cmek     = var.cmek
}

###############################################################################
# Centralized log sinks → bucket
###############################################################################
module "log_sinks" {
  source = "./modules/log_sinks"

  project_id  = var.project_id
  sink_name   = "all-logs-to-bucket"
  destination = "storage.googleapis.com/${var.image_bucket}"
}

###############################################################################
# Monitoring / dashboards / alerting
###############################################################################
module "monitoring" {
  source     = "./modules/monitoring"
  project_id = var.project_id
  region     = var.region # <-- add this line
}

###############################################################################
# Cloud SQL (private CMEK)
###############################################################################
module "sql" {
  source = "./modules/sql"

  project_id      = var.project_id
  region          = var.region
  private_network = module.vpc.vpc_self_link
  cmek            = var.cmek
  iam_sql_user    = var.iam_sql_user
}

###############################################################################
# Vertex AI resources (Workbench Index etc.)
###############################################################################
module "vertex_ai" {
  source = "./modules/vertex_ai"

  project_id      = var.project_id
  region          = var.region
  subnet          = module.vpc.subnet_self_link
  network         = module.vpc.vpc_self_link
  service_account = var.custom_service_account_email
}
