variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile Terraform uses for authentication."
  type        = string
  default     = "observability"
}

variable "env" {
  description = "Environment name used in tagging and resource naming."
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Owner identifier for the Owner tag."
  type        = string
  default     = "chiemela"
}

variable "domain" {
  description = "Base DNS domain under which observability endpoints are published."
  type        = string
  default     = "observability.chiemela.dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the dedicated observability VPC."
  type        = string
  default     = "10.100.0.0/16"
}

variable "eks_version" {
  description = "Kubernetes minor version for the EKS cluster."
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for the EKS managed node group."
  type        = string
  default     = "t3.medium"
}

variable "eks_node_desired_size" {
  description = "Desired node count for the EKS managed node group."
  type        = number
  default     = 3
}
