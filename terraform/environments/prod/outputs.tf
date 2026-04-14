output "agent_service_url" {
  value       = module.agent_cloudrun.service_url
  description = "The URL of the deployed agent service"
}

output "agent_service_account" {
  value       = module.agent_cloudrun.service_account_email
  description = "The dedicated service account used by the agent"
}

output "client_service_url" {
  value       = module.client_cloudrun.service_url
  description = "The public URL of the deployed React application"
}
