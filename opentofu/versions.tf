terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.71.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.16.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

### eu-central-1 ###
provider "aws" {
  alias  = "eu-central-1"
  region = "eu-central-1"
}

provider "kubernetes" {
  alias = "eu-central-1"

  host                   = module.eu-central-1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eu-central-1.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eu-central-1.cluster_name]
  }
}

provider "helm" {
  alias = "eu-central-1"

  kubernetes {
    host                   = module.eu-central-1.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eu-central-1.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eu-central-1.cluster_name]
    }
  }
}

provider "kubectl" {
  alias = "eu-central-1"

  apply_retry_count      = 5
  host                   = module.eu-central-1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eu-central-1.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eu-central-1.cluster_name]
  }
}

### eu-west-3 ###
provider "aws" {
  alias  = "eu-west-3"
  region = "eu-west-3"
}

provider "kubernetes" {
  alias = "eu-west-3"

  host                   = module.eu-west-3.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eu-west-3.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eu-west-3.cluster_name]
  }
}

provider "helm" {
  alias = "eu-west-3"

  kubernetes {
    host                   = module.eu-west-3.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eu-west-3.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eu-west-3.cluster_name]
    }
  }
}

provider "kubectl" {
  alias = "eu-west-3"

  apply_retry_count      = 5
  host                   = module.eu-west-3.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eu-west-3.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eu-west-3.cluster_name]
  }
}

### eu-south-1 ###
provider "aws" {
  alias  = "eu-south-1"
  region = "eu-south-1"
}

# The provider is only used to fetch the public ECR authorization data:
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecrpublic_authorization_token
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "random" {}

