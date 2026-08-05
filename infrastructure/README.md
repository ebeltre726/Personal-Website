# Infrastructure layout

- bootstrap/: provisions the shared Terraform remote state bucket and DynamoDB lock table.
- app/: provisions the application resources (S3, CloudFront, API Gateway, Lambda, SSM, etc.).

## Bootstrap

Run this first once:

```bash
cd infrastructure/bootstrap
terraform init
terraform apply
```

## App

After the bootstrap resources exist, run:

```bash
cd infrastructure/app
terraform init
terraform apply
```
