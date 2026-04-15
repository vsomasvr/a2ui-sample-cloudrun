resource "google_cloud_run_v2_service" "client_service" {
  provider = google-beta
  name     = var.service_name
  location = var.region
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_ALL"
  iap_enabled = true

  template {
    service_account = google_service_account.client_sa.email
    containers {
      image = var.image_url
      
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }

      env {
        name  = "AGENT_URL"
        value = var.agent_url
      }
    }
  }

  depends_on = [
    google_service_account.client_sa
  ]
}
