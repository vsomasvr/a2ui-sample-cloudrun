output "agent_service_url" {
  value       = module.agent_cloudrun.service_url
  description = "The URL of the deployed agent service"
}

output "agent_service_account" {
  value       = module.agent_cloudrun.service_account_email
  description = "The dedicated service account used by the agent"
}
