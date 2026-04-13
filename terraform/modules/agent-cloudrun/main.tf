resource "google_cloud_run_v2_service" "agent_service" {
  name     = var.service_name
  location = var.region
  project  = var.project_id
  
  template {
    service_account = google_service_account.agent_sa.email
    containers {
      image = var.image_url
      
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
      }

      env {
        name  = "VERTEX_PROJECT"
        value = var.project_id
      }
      env {
        name  = "VERTEX_LOCATION"
        value = var.region
      }
      env {
        name  = "GOOGLE_GENAI_USE_VERTEXAI"
        value = var.use_vertex_ai ? "TRUE" : "FALSE"
      }
    }
  }

  depends_on = [
    google_service_account.agent_sa
  ]
}
