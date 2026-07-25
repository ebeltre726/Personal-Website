# Personal Website

Second attempt at a personal professional website, aimed at ease of code editing, neatness, and following best practices.

## Goal
Create a mobile-first professional portfolio website with minimal functionality that can be showcased to future employers, while allowing for future design and functionality expansion.

## Progress
The website is created and public, and future updates aim to improve CSS responsiveness and expand the projects section with YouTube or GitHub content, along with the implementation of Terraform for CI/CD deployments.

## Terraform deployment
This repository now includes a Terraform-based deployment setup for:
- My S3-hosted static website
- My CloudFront CDN distribution
- My Lambda-backed API Gateway endpoint for the contact form
- ACM certificate support for my domain
- GitHub Actions-based CI/CD deployment

### Infrastructure layout
- infra/main.tf - core Terraform resources
- infra/variables.tf - configurable inputs
- infra/outputs.tf - outputs for deployment values
- infra/lambda/contact-form/index.js - Lambda handler for the contact form
- .github/workflows/terraform.yml - GitHub Actions workflow

### Required GitHub variables
Set these in GitHub repository settings -> Secrets and variables -> Actions -> Variables:
- DOMAIN_NAME
- HOSTINGER_ZONE_ID
- EMAILJS_SERVICE_ID
- EMAILJS_TEMPLATE_ID
- EMAILJS_PUBLIC_KEY
- AWS_PORTFOLIO_ROLE

### Notes
- The GitHub Actions workflow assumes an AWS role using OIDC.
- The Terraform configuration expects the domain to be managed through Route 53 or a delegated zone that Route 53 can update.
- Because DNS is currently hosted at Hostinger, you will need to create the ACM validation records and configure the domain records through Hostinger or a delegated DNS zone.

### Terraform commands
```bash
cd infra
terraform init
terraform plan
terraform apply
```
