# Enable additional essential APIs upfront

resource "google_project_service" "enable_serviceusage" {
  project            = var.project_id
  service            = "serviceusage.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "enable_orgpolicy" {
  project            = var.project_id
  service            = "orgpolicy.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.enable_serviceusage]
}

resource "google_project_service" "enable_cloudkms" {
  project            = var.project_id
  service            = "cloudkms.googleapis.com"
  disable_on_destroy = false
  depends_on         = [google_project_service.enable_serviceusage]
}
