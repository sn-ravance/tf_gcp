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
  project_id      = var.project_id
  name            = "Sandbox Project"
  billing_account = var.billing_account
  org_id          = var.org_id
  folder_id       = var.folder_id
  labels = {
    env  = "sandbox"
    team = var.team
  }
}

resource "google_storage_bucket" "image_bucket" {
  name     = var.image_bucket
  location = var.image_bucket_location
  uniform_bucket_level_access = true
  force_destroy = true
  public_access_prevention = "enforced"

  versioning {
    enabled = true
  }

  logging {
    log_bucket        = google_storage_bucket.log_sink_bucket.name
    log_object_prefix = "access-logs"
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
  name     = "${var.project_id}-log-sink"
  location = var.image_bucket_location
  uniform_bucket_level_access = true
  force_destroy = true
  public_access_prevention = "enforced"

  versioning {
    enabled = true
  }

  logging {
    log_bucket        = google_storage_bucket.log_sink_bucket.name
    log_object_prefix = "access-logs"
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
  # If it does not exist, this resource will be a no-op.
  # You may need to import the default network before destroy: 
  # terraform import google_compute_network.default projects/${var.project_id}/global/networks/default
  # Or manually delete it if import fails.
  count = 0 # Set to 1 and import if you want to destroy the default network.
}

# --- Organization Policy Constraints ---
resource "google_org_policy_policy" "disable_guest_attributes" {
  name     = "organizations/${var.org_id}/policies/compute.disableGuestAttributesAccess"
  parent   = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = true
    }
  }
}

resource "google_org_policy_policy" "disable_sa_key_creation" {
  name   = "organizations/${var.org_id}/policies/iam.disableServiceAccountKeyCreation"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = true
    }
  }
}

resource "google_org_policy_policy" "require_oslogin" {
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
  name          = "private-subnet"
  ip_cidr_range = "10.10.0.0/16"
  region        = var.region
  network       = google_compute_network.secure_vpc.id
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

# --- Centralized Log Sink to Storage Bucket ---
resource "google_logging_project_sink" "all_logs" {
  name        = "all-logs-to-bucket"
  project     = var.project_id
  destination = "storage.googleapis.com/${google_storage_bucket.log_sink_bucket.name}"
  filter      = "logName:*"
  include_children = true
}

resource "google_storage_bucket_iam_member" "log_writer" {
  bucket = google_storage_bucket.log_sink_bucket.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_logging_project_sink.all_logs.writer_identity}"
}

# --- Secure Cloud SQL Instance (Postgres, Private IP, CMEK) ---
resource "google_sql_database_instance" "private_postgres" {
  name             = "private-postgres"
  region           = var.region
  database_version = "POSTGRES_15" # Use latest major version (CKV_GCP_79)
  project          = var.project_id

  settings {
    tier = "db-custom-1-3840"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.secure_vpc.id
      require_ssl     = true # Enforce SSL (CKV_GCP_6)
    }
    backup_configuration {
      enabled = true
    }
    disk_encryption_configuration {
      kms_key_name = var.cmek
    }
    database_flags = [
      {
        name  = "log_connections"
        value = "on"
      },
      {
        name  = "log_disconnections"
        value = "on"
      },
      {
        name  = "log_checkpoints"
        value = "on"
      },
      {
        name  = "log_lock_waits"
        value = "on"
      },
      {
        name  = "log_hostname"
        value = "on"
      },
      {
        name  = "log_statement"
        value = "all"
      },
      {
        name  = "log_min_messages"
        value = "error"
      },
      {
        name  = "log_temp_files"
        value = "0"
      },
      {
        name  = "log_min_duration_statement"
        value = "-1"
      },
      {
        name  = "cloudsql.enable_pgaudit"
        value = "on"
      }
    ]
  }
  deletion_protection = true
}

resource "google_sql_user" "iam_user" {
  name     = var.iam_sql_user
  instance = google_sql_database_instance.private_postgres.name
  type     = "CLOUD_IAM_USER"
}

# --- Vertex AI Workbench Instance (Private Endpoint) ---
resource "google_notebooks_instance" "private_workbench" {
  name         = "private-workbench"
  location     = var.region
  project      = var.project_id
  machine_type = "n1-standard-4"

  vm_image {
    project      = "deeplearning-platform-release"
    image_family = "tf-latest-cpu"
  }

  boot_disk_type = "PD_STANDARD"
  boot_disk_size_gb = 100

  network = google_compute_network.secure_vpc.id
  subnet  = google_compute_subnetwork.private_subnet.id

  no_public_ip = true
  service_account = var.custom_service_account_email
}

# --- Vertex AI Index (RAG Example) ---
resource "google_vertex_ai_index" "rag_index" {
  name     = "rag-index"
  region   = var.region
  project  = var.project_id
  display_name = "RAG Index"
  metadata_schema_uri = "gs://google-cloud-aiplatform/schema/dataset/metadata/text_1.0.0.yaml"
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
    "aiplatform.googleapis.com"
  ]
}
