terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id = var.project_id
  region     = var.region
  repo_name  = var.registry_repo_name
}

module "agent_cloudrun" {
  source = "../../modules/agent-cloudrun"

  project_id    = var.project_id
  region        = var.region
  image_url     = var.agent_image_url
  service_name  = "a2ui-agent-prod"
  use_vertex_ai = var.use_vertex_ai
}
