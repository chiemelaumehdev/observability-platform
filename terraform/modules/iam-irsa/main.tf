locals {
  oidc_issuer = replace(var.oidc_provider_url, "https://", "")
}

data "aws_iam_policy_document" "tempo_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
    ]
    resources = [
      var.tempo_bucket_arn,
      "${var.tempo_bucket_arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.tempo_kms_key_arn]
  }
}

data "aws_iam_policy_document" "mimir_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
    ]
    resources = [
      var.mimir_bucket_arn,
      "${var.mimir_bucket_arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.mimir_kms_key_arn]
  }
}

data "aws_iam_policy_document" "loki_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
    ]
    resources = [
      var.loki_bucket_arn,
      "${var.loki_bucket_arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [var.loki_kms_key_arn]
  }
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = ["*"]
  }
}

locals {
  roles = {
    tempo = {
      namespace       = "observability"
      service_account = "tempo"
      policy          = data.aws_iam_policy_document.tempo_s3.json
    }
    mimir = {
      namespace       = "observability"
      service_account = "mimir"
      policy          = data.aws_iam_policy_document.mimir_s3.json
    }
    loki = {
      namespace       = "observability"
      service_account = "loki"
      policy          = data.aws_iam_policy_document.loki_s3.json
    }
    external-secrets = {
      namespace       = "external-secrets"
      service_account = "external-secrets"
      policy          = data.aws_iam_policy_document.external_secrets.json
    }
  }
}

data "aws_iam_policy_document" "trust" {
  for_each = local.roles

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:${each.value.namespace}:${each.value.service_account}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "irsa" {
  for_each = local.roles

  name               = "observability-${each.key}-irsa"
  assume_role_policy = data.aws_iam_policy_document.trust[each.key].json
}

resource "aws_iam_role_policy" "irsa" {
  for_each = local.roles

  name   = "${each.key}-policy"
  role   = aws_iam_role.irsa[each.key].id
  policy = each.value.policy
}
