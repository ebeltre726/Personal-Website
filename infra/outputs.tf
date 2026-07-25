output "bucket_name" {
  value = aws_s3_bucket.site.bucket
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.site.domain_name
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.contact_form.api_endpoint
}

output "lambda_function_name" {
  value = aws_lambda_function.contact_form.function_name
}
