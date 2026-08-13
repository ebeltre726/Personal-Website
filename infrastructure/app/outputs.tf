output "site_bucket_name" {
  value = aws_s3_bucket.site.bucket
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "frontend_deploy_role_arn" {
  value = aws_iam_role.frontend_deploy.arn
}

output "frontend_api_url" {
  value = local.api_gateway_url
}