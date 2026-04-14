output "service_url" {
  value       = google_cloud_run_v2_service.agent_service.uri
  description = "The URL of the deployed Cloud Run service"
}

output "service_account_email" {
  value       = google_service_account.agent_sa.email
  description = "The email of the dedicated service account"
}
output "service_name" {
  value       = google_cloud_run_v2_service.agent_service.name
  description = "The name of the agent service"
}
