variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region (e.g. us-central1)"
  default     = "us-central1"
}

variable "agent_image_url" {
  type        = string
  description = "Container image URL for the agent"
}

variable "use_vertex_ai" {
  type        = bool
  description = "Whether to use Vertex AI for the agent"
  default     = true
}

variable "registry_repo_name" {
  type        = string
  description = "Name of the Artifact Registry repository prefix parsed from tfvars"
}

variable "client_image_url" {
  type        = string
  description = "Container image URL for the React BFF client"
}

variable "agent_base_url" {
  type        = string
  description = "The public-facing URL of the agent Cloud Run service (for the agent card). Set after first deploy."
  default     = ""
}

variable "iap_authorized_users" {
  type        = list(string)
  description = "List of IAP authorized users"
  default     = []
}
