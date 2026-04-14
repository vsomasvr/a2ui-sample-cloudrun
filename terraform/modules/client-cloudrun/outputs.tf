output "service_url" {
  value       = google_cloud_run_v2_service.client_service.uri
  description = "The public URL of the React Frontend"
}
