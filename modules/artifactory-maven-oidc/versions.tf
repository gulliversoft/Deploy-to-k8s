terraform {
  required_providers {
    artifactory = {
      source  = "jfrog/artifactory"
      version = "12.11.14"
    }
    platform = {
      source = "jfrog/platform"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}
