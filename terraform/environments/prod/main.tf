terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
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
  base_url      = var.agent_base_url
}

module "client_cloudrun" {
  source = "../../modules/client-cloudrun"

  project_id         = var.project_id
  region             = var.region
  image_url          = var.client_image_url
  service_name       = "a2ui-client-prod"
  agent_url          = module.agent_cloudrun.service_url
  agent_service_name = module.agent_cloudrun.service_name
  iap_authorized_users = var.iap_authorized_users

  depends_on = [module.agent_cloudrun]
}
