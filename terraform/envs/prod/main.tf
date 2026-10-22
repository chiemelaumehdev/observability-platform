terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
  }

  # Backend values are supplied via -backend-config=backend.hcl.
  backend "s3" {}
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project    = "observability"
      ManagedBy  = "terraform"
      Env        = var.env
      Owner      = var.owner
      Repository = "github.com/chiemelaumehdev/observability-platform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  name_prefix = "observability"
  domain      = var.domain
}

# -----------------------------------------------------------------------------
# Phase 2 modules are added here as they come online.
#
#   module "vpc"           { source = "../../modules/vpc" ...           }
#   module "s3_storage"    { source = "../../modules/s3-storage" ...    }
#   module "ecr"           { source = "../../modules/ecr" ...           }
#   module "rds_grafana"   { source = "../../modules/rds-grafana" ...   }
#   module "eks"           { source = "../../modules/eks" ...           }
#   module "iam_irsa"      { source = "../../modules/iam-irsa" ...      }
#
# Each module is independently initialized and planned.
# -----------------------------------------------------------------------------
