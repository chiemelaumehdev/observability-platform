variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes minor version."
  type        = string
}

variable "vpc_id" {
  description = "VPC id for the cluster."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the cluster nodes and control plane ENIs."
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for the default managed node group."
  type        = string
}

variable "node_desired_size" {
  description = "Desired node count for the default managed node group."
  type        = number
}
