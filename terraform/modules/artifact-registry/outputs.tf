output "repo_id" {
  value       = google_artifact_registry_repository.docker_repo.id
  description = "The ID of the artifact registry repository"
}

output "repo_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repo_name}"
  description = "The base URL for the repository"
}
