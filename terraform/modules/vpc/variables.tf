variable "name" {
  description = "VPC name."
  type        = string
}

variable "cidr" {
  description = "Primary CIDR block."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "azs" {
  description = "Availability zones."
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs."
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs."
  type        = list(string)
}
