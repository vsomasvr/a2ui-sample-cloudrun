data "google_project" "project" {
  project_id = var.project_id
}

resource "google_service_account" "client_sa" {
  account_id   = "${var.service_name}-sa"
  display_name = "Service Account for A2UI React Client"
  project      = var.project_id
}

# Grant the Client SA permission to securely invoke the backend Agent Service
resource "google_cloud_run_service_iam_member" "client_to_agent_invoker" {
  location = var.region
  project  = var.project_id
  service  = var.agent_service_name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.client_sa.email}"
}

# The React Front-End BFF itself must be publicly accessible on the internet
resource "google_cloud_run_service_iam_member" "public_client_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloud_run_v2_service.client_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-iap.iam.gserviceaccount.com"
}

# Ensure the provided users are given access via Identity-Aware Proxy to the exact service resource
resource "google_iap_web_cloud_run_service_iam_binding" "iap_access" {
  project = var.project_id
  location = var.region
  cloud_run_service_name = google_cloud_run_v2_service.client_service.name
  role = "roles/iap.httpsResourceAccessor"
  members = var.iap_authorized_users
}
