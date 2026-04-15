variable "project_id" {
  type        = string
  description = "The GCP Project ID"
}

variable "region" {
  type        = string
  description = "The GCP Region"
}

variable "service_name" {
  type        = string
  description = "Name of the Cloud Run service"
  default     = "a2ui-agent"
}

variable "image_url" {
  type        = string
  description = "Container image URL for the agent"
}

variable "service_account_id" {
  type        = string
  description = "The ID of the custom service account to create for this service"
  default     = "a2ui-agent-sa"
}

variable "use_vertex_ai" {
  type        = bool
  description = "Whether the agent should use Vertex AI (sets GOOGLE_GENAI_USE_VERTEXAI)"
  default     = true
}

variable "base_url" {
  type        = string
  description = "The public-facing URL for the agent card. Set to the Cloud Run service URL after first deploy."
  default     = ""
}
