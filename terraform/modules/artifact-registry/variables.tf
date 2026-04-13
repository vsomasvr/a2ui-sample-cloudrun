variable "project_id" {
  type        = string
  description = "GCP Project ID"
}

variable "region" {
  type        = string
  description = "GCP Region for the Artifact Registry"
}

variable "repo_name" {
  type        = string
  description = "Name of the Docker repository in Artifact Registry"
}
