resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.repo_name
  description   = "Docker registry for A2UI sample agent"
  format        = "DOCKER"
  project       = var.project_id
}
