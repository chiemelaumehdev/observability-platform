terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.region

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

locals {
  account_id   = data.aws_caller_identity.current.account_id
  region       = var.region
  name_prefix  = "observability"
  cluster_name = "${local.name_prefix}-eks"

  azs = ["${var.region}a", "${var.region}b", "${var.region}c"]

  private_subnets = ["10.100.0.0/19", "10.100.32.0/19", "10.100.64.0/19"]
  public_subnets  = ["10.100.96.0/20", "10.100.112.0/20", "10.100.128.0/20"]
}

module "vpc" {
  source = "../../modules/vpc"

  name            = "${local.name_prefix}-vpc"
  cidr            = var.vpc_cidr
  region          = local.region
  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
}

module "s3_storage" {
  source = "../../modules/s3-storage"

  name_prefix = local.name_prefix
  account_id  = local.account_id
  region      = local.region
}

module "ecr" {
  source = "../../modules/ecr"

  name = "observability-app"
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  cluster_version    = var.eks_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  node_instance_type = var.eks_node_instance_type
  node_desired_size  = var.eks_node_desired_size
}

module "rds_grafana" {
  source = "../../modules/rds-grafana"

  name                       = local.name_prefix
  vpc_id                     = module.vpc.vpc_id
  subnet_ids                 = module.vpc.private_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]
}

module "iam_irsa" {
  source = "../../modules/iam-irsa"

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.cluster_oidc_issuer_url

  tempo_bucket_arn  = module.s3_storage.bucket_arns["tempo"]
  tempo_kms_key_arn = module.s3_storage.kms_key_arns["tempo"]
  mimir_bucket_arn  = module.s3_storage.bucket_arns["mimir"]
  mimir_kms_key_arn = module.s3_storage.kms_key_arns["mimir"]
  loki_bucket_arn   = module.s3_storage.bucket_arns["loki"]
  loki_kms_key_arn  = module.s3_storage.kms_key_arns["loki"]
}
