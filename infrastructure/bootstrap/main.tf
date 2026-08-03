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
  app_name                = "Personal-Website"
  tfstate_bucket_name     = "aws-beltre-portfolio-tfstate"
  tfstate_lock_table_name = "aws-beltre-portfolio-tf-locks"
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

resource "aws_dynamodb_table" "tfstate_locks" {
  name         = local.tfstate_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = local.tfstate_lock_table_name
    Environment = var.environment
    Project     = local.app_name
  }
}

output "tfstate_bucket_name" {
  value = aws_s3_bucket.tfstate.bucket
}

output "tfstate_lock_table_name" {
  value = aws_dynamodb_table.tfstate_locks.name
}
