terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >v6.00 breaks compatibility with this blueprint
      version = ">= 5.34, < 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24"
    }
    helm = {
      source = "hashicorp/helm"
      # v3.0 breaks compatibility with this blueprint
      version = ">= 2.9, < 3.0"
    }
  }

}
