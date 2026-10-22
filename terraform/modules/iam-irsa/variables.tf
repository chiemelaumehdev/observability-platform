variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's OIDC provider."
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS cluster's OIDC provider (https://... form)."
  type        = string
}

variable "tempo_bucket_arn" {
  description = "ARN of the Tempo blocks S3 bucket."
  type        = string
}

variable "tempo_kms_key_arn" {
  description = "ARN of the Tempo bucket KMS key."
  type        = string
}

variable "mimir_bucket_arn" {
  description = "ARN of the Mimir blocks S3 bucket."
  type        = string
}

variable "mimir_kms_key_arn" {
  description = "ARN of the Mimir bucket KMS key."
  type        = string
}

variable "loki_bucket_arn" {
  description = "ARN of the Loki chunks S3 bucket."
  type        = string
}

variable "loki_kms_key_arn" {
  description = "ARN of the Loki bucket KMS key."
  type        = string
}
