terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  app_name            = "Personal-Website"
  tfstate_bucket_name = "aws-beltre-portfolio-tfstate"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions_assume_role" {
  count = var.create_github_actions_role && var.github_repository != "" ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"]
    }
  }
}

data "aws_iam_policy_document" "terraform_deploy_permissions" {
  count = var.create_github_actions_role && var.github_repository != "" ? 1 : 0

  statement {
    sid    = "TerraformStateAccess"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:PutBucketVersioning"
    ]
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*"
    ]
  }

  statement {
    sid    = "TerraformAppInfrastructureAccess"
    effect = "Allow"
    actions = [
      "acm:*",
      "apigateway:*",
      "cloudfront:*",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:ListRoles",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateRole",
      "lambda:*",
      "route53:*",
      "ssm:*",
      "s3:*",
      "kms:*",
      "logs:*"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "PassRoleToLambda"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*"
    ]
  }
}

resource "aws_s3_bucket" "tfstate" {
  bucket = local.tfstate_bucket_name

  tags = {
    Name        = local.tfstate_bucket_name
    Environment = var.environment
    Project     = local.app_name
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_actions_role && var.github_repository != "" ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c58d9b9a6b4f4f4d0d8c8d7e0f4e4b4d4c5e8f6"]

  tags = {
    Environment = var.environment
    Project     = local.app_name
  }
}

resource "aws_iam_role" "terraform_deploy" {
  count = var.create_github_actions_role && var.github_repository != "" ? 1 : 0

  name               = var.terraform_deployment_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role[0].json

  tags = {
    Environment = var.environment
    Project     = local.app_name
  }
}

resource "aws_iam_role" "secret_update" {
  name = "ssm-secret-update-role"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role[0].json
}

resource "aws_iam_role_policy" "terraform_deploy" {
  count = var.create_github_actions_role && var.github_repository != "" ? 1 : 0

  name   = "terraform-deploy-policy"
  role   = aws_iam_role.terraform_deploy[0].id
  policy = data.aws_iam_policy_document.terraform_deploy_permissions[0].json
}

data "aws_iam_role" "existing" {
  count = var.create_github_actions_role ? 0 : 1
  name  = var.terraform_deployment_role_name
}

resource "aws_iam_role_policy" "secret_update" {
  role = aws_iam_role.secret_update.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/portfolio/emailjs/private-key"
      }
    ]
  })
}

output "tfstate_bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "terraform_deployment_role_name" {
  value = var.create_github_actions_role ? aws_iam_role.terraform_deploy[0].name : data.aws_iam_role.existing[0].name
}

output "terraform_deployment_role_arn" {
  value = var.create_github_actions_role ? aws_iam_role.terraform_deploy[0].arn : data.aws_iam_role.existing[0].arn
}

output "secret_update_role_arn" {
  value = aws_iam_role.secret_update.arn
}

output "github_oidc_provider_arn" {
  value = var.create_github_actions_role && var.github_repository != "" ? aws_iam_openid_connect_provider.github[0].arn : null
}
