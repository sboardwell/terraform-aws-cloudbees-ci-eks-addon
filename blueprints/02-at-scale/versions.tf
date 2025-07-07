terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >v6.00 breaks compatibility with this blueprint
      version = "= 5.100.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.24"
    }
    helm = {
      source = "hashicorp/helm"
      # >v3.x breaks compatibility with this blueprint
      version = "= 2.17.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }

    time = {
      source  = "hashicorp/time"
      version = ">= 0.7.1"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.1"
    }


  }

}
