variable "name_prefix" {
  description = "Prefix for bucket and KMS resource names."
  type        = string
  default     = "observability"
}

variable "account_id" {
  description = "AWS account id for bucket name uniqueness."
  type        = string
}

variable "region" {
  description = "AWS region used in bucket names."
  type        = string
}

variable "allow_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets. Lab only."
  type        = bool
  default     = true
}
