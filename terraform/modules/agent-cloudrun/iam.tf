resource "google_service_account" "agent_sa" {
  account_id   = var.service_account_id
  display_name = "Service Account for A2UI Agent"
  project      = var.project_id
}

# Example: Granting logging privileges so the agent can write structured logs
resource "google_project_iam_member" "agent_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

# Granting Vertex AI User privileges so the agent can interact with Vertex AI
resource "google_project_iam_member" "agent_sa_vertex_ai" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.agent_sa.email}"
}

# If in the future you need to expose this without authentication (not recommended for secure agents),
# you would uncomment something like this:
# resource "google_cloud_run_service_iam_member" "public_invoker" {
#   location = var.region
#   project  = var.project_id
#   service  = google_cloud_run_v2_service.agent_service.name
#   role     = "roles/run.invoker"
#   member   = "allUsers"
# }
