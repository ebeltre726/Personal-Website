terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "aws-beltre-portfolio-tfstate"
    key          = "app/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "github" {
  owner = "ebeltre726"
}

locals {
  app_name                      = "Personal-Website"
  bucket_name                   = "aws-beltre-portfolio-bucket"
  origin_id                     = "aws-beltre-origin-id"
  lambda_name                   = "sendContactEmail"
  api_name                      = "aws-portfolio-contact-api"
  project_name                  = "portfolio"
  frontend_deploy_role_name     = "${local.app_name}-frontend-deploy"
  github_oidc_provider_arn      = data.terraform_remote_state.bootstrap.outputs.github_oidc_provider_arn
  github_repository             = data.terraform_remote_state.bootstrap.outputs.github_repository
  github_branch                 = data.terraform_remote_state.bootstrap.outputs.github_branch
  ssm_parameter_name            = "/${local.project_name}/emailjs/private-key"
  ssm_parameter_placeholder_val = var.emailjs_private_key != "" ? var.emailjs_private_key : "REPLACE_WITH_GHA_SECRET"
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "bootstrap" {
  backend = "s3"

  config = {
    bucket = "aws-beltre-portfolio-tfstate"
    key    = "bootstrap/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {

  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    effect = "Allow"

    principals {
      type = "Federated"

      identifiers = [
        local.github_oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test = "StringLike"

      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${local.github_repository}:ref:refs/heads/${local.github_branch}"
      ]
    }
  }
}

resource "github_actions_variable" "frontend_role_arn" {
  repository = local.github_repository

  variable_name = "FRONTEND_DEPLOY_ROLE_ARN"
  value         = aws_iam_role.frontend_deploy.arn
}

resource "github_actions_variable" "site_bucket_name" {
  repository = local.github_repository

  variable_name = "FRONTEND_BUCKET_NAME"
  value         = aws_s3_bucket.site.bucket
}

resource "github_actions_variable" "cloudfront_distribution_id" {
  repository = "Personal-Website"

  variable_name = "CLOUDFRONT_DISTRIBUTION_ID"
  value         = aws_cloudfront_distribution.site.id
}

resource "aws_iam_role" "frontend_deploy" {
  name = local.frontend_deploy_role_name

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

resource "null_resource" "lambda_dependencies" {
  triggers = {
    index_hash   = filesha256("${path.module}/../lambda/contact-form/index.js")
    package_hash = filesha256("${path.module}/../lambda/contact-form/package.json")
  }

  provisioner "local-exec" {
    command = "npm install --prefix ${path.module}/../lambda/contact-form --omit=dev"
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/contact-form"
  output_path = "${path.module}/../lambda/contact-form/index.zip"

  depends_on = [null_resource.lambda_dependencies]
}

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name

  tags = {
    Name        = local.bucket_name
    Environment = var.environment
    Project     = local.app_name
  }
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontGetObject"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.site.arn}/*"]
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.domain_name}-oac"
  description                       = "OAC for ${var.domain_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = var.domain_name != "" ? [var.domain_name] : []

  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = local.origin_id

    origin_access_control_id = aws_cloudfront_origin_access_control.site.id

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.origin_id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.site.arn

    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  tags = {
    Environment = var.environment
    Project     = local.app_name
  }
}

resource "aws_acm_certificate" "site" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
    Project     = local.app_name
  }
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = []
}

resource "aws_ssm_parameter" "emailjs_private_key" {
  name        = local.ssm_parameter_name
  description = "EmailJS private key for the contact form Lambda"
  type        = "SecureString"
  value       = local.ssm_parameter_placeholder_val

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = var.environment
    Project     = local.app_name
  }
}

resource "aws_lambda_function" "contact_form" {
  filename         = data.archive_file.lambda.output_path
  function_name    = local.lambda_name
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  timeout          = 30
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      EMAILJS_SERVICE_ID                 = var.emailjs_service_id
      EMAILJS_TEMPLATE_ID                = var.emailjs_template_id
      EMAILJS_PUBLIC_KEY                 = var.emailjs_public_key
      EMAILJS_PRIVATE_KEY_PARAMETER_NAME = aws_ssm_parameter.emailjs_private_key.name
      ALLOWED_ORIGINS                    = var.allowed_origins
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "${local.lambda_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Effect = "Allow"
    }]
  })
}

resource "aws_iam_role_policy" "frontend_deploy" {
  name = "frontend-deploy-policy"
  role = aws_iam_role.frontend_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          aws_s3_bucket.site.arn
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "${aws_s3_bucket.site.arn}/*"
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "cloudfront:CreateInvalidation"
        ]

        Resource = [
          aws_cloudfront_distribution.site.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ssm" {
  name = "${local.lambda_name}-ssm-read"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = [aws_ssm_parameter.emailjs_private_key.arn]
      },
      {
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Resource = [
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      }
    ]
  })
}

resource "aws_apigatewayv2_api" "contact_form" {
  name          = local.api_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "contact_form" {
  api_id                 = aws_apigatewayv2_api.contact_form.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.contact_form.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "contact_form" {
  api_id    = aws_apigatewayv2_api.contact_form.id
  route_key = "POST /sendContactEmail"
  target    = "integrations/${aws_apigatewayv2_integration.contact_form.id}"
}

resource "aws_apigatewayv2_route" "contact_form_options" {
  api_id    = aws_apigatewayv2_api.contact_form.id
  route_key = "OPTIONS /sendContactEmail"
  target    = "integrations/${aws_apigatewayv2_integration.contact_form.id}"
}

resource "aws_apigatewayv2_stage" "contact_form" {
  api_id      = aws_apigatewayv2_api.contact_form.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_form.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.contact_form.execution_arn}/*/*"
}

resource "aws_route53_record" "site_a" {
  count   = var.hostinger_zone_id != "" ? 1 : 0
  zone_id = var.hostinger_zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_aaaa" {
  count   = var.hostinger_zone_id != "" ? 1 : 0
  zone_id = var.hostinger_zone_id
  name    = var.domain_name
  type    = "AAAA"
  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
