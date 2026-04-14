variable "project_id" { type = string }
variable "region" { type = string }

variable "image_url" {
  type        = string
  description = "Container image URL for the React BFF client"
}

variable "service_name" {
  type        = string
  default     = "a2ui-client"
  description = "Name of the client Cloud Run service"
}

variable "agent_url" {
  type        = string
  description = "The internal Cloud Run URL of the agent service to proxy traffic to"
}

variable "agent_service_name" {
  type        = string
  description = "The name of the agent Cloud Run service (used for IAM bindings)"
}
