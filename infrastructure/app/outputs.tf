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

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "route53_zone_id" {
  value = aws_route53_zone.site.zone_id
}

output "route53_name_servers" {
  description = "Set these as the custom nameservers for the domain in Hostinger"
  value       = aws_route53_zone.site.name_servers
}
