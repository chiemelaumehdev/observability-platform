output "bucket_names" {
  value = { for k, v in aws_s3_bucket.signal : k => v.id }
}

output "bucket_arns" {
  value = { for k, v in aws_s3_bucket.signal : k => v.arn }
}

output "kms_key_arns" {
  value = { for k, v in aws_kms_key.signal : k => v.arn }
}

output "kms_key_ids" {
  value = { for k, v in aws_kms_key.signal : k => v.key_id }
}
