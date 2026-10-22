variable "cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "service_name" {
  description = "ECS service name (also used as log group suffix and IAM role prefix)."
  type        = string
}

variable "app_image" {
  description = "Full container image reference for the app container."
  type        = string
}

variable "collector_endpoint" {
  description = "host:port of the OTel Collector Gateway the ADOT sidecar forwards to."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name stamped on telemetry."
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR for intra-VPC ingress rules."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet ids for the ECS task network interfaces."
  type        = list(string)
}

variable "desired_count" {
  description = "Number of task replicas."
  type        = number
  default     = 1
}
