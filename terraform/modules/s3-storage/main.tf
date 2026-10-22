locals {
  buckets = {
    tempo = {
      ia_days     = 7
      expire_days = 90
    }
    mimir = {
      ia_days     = 30
      expire_days = 395
    }
    loki = {
      ia_days     = 7
      expire_days = 90
    }
  }
}

resource "aws_kms_key" "signal" {
  for_each = local.buckets

  description             = "KMS key for ${var.name_prefix}-${each.key}-storage"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name    = "${var.name_prefix}-${each.key}-kms"
    Purpose = "observability-${each.key}-storage"
  }
}

resource "aws_kms_alias" "signal" {
  for_each      = local.buckets
  name          = "alias/${var.name_prefix}-${each.key}"
  target_key_id = aws_kms_key.signal[each.key].key_id
}

resource "aws_s3_bucket" "signal" {
  for_each      = local.buckets
  bucket        = "${var.name_prefix}-${each.key}-blocks-${var.account_id}-${var.region}"
  force_destroy = var.allow_destroy

  tags = {
    Name   = "${var.name_prefix}-${each.key}-blocks"
    Signal = each.key
  }
}

resource "aws_s3_bucket_versioning" "signal" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.signal[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "signal" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.signal[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.signal[each.key].arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "signal" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.signal[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "signal" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.signal[each.key].id

  rule {
    id     = "transition-and-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = each.value.ia_days
      storage_class = "INTELLIGENT_TIERING"
    }

    expiration {
      days = each.value.expire_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "deny_insecure_transport" {
  for_each = local.buckets

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.signal[each.key].arn,
      "${aws_s3_bucket.signal[each.key].arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "signal" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.signal[each.key].id
  policy   = data.aws_iam_policy_document.deny_insecure_transport[each.key].json
}
