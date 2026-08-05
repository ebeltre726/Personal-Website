variable "aws_region" {
  description = "AWS region for the bootstrap resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "github_repository" {
  description = "GitHub repository in owner/repo format for the OIDC trust policy"
  type        = string
  default     = "ebeltre726/Personal-Website"
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the Terraform deployment role"
  type        = string
  default     = "main"
}

variable "terraform_deployment_role_name" {
  description = "Name of the IAM role used by GitHub Actions for Terraform deployment"
  type        = string
  default     = "github-actions-terraform-deploy"
}

variable "create_github_actions_role" {
  description = "Set to false to reuse an existing GitHub Actions Terraform role instead of creating one"
  type        = bool
  default     = true
}
