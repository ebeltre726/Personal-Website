# Personal-Website Project Structure

## 🧱 Architecture Overview

### 📦 Frontend

- Built with Vite (`vite.config.js`)
- JavaScript-based with Jest testing setup (`jest.config.js`, `package.json`)
- No explicit AWS SDK dependencies detected in frontend code

### 🧱 Infrastructure

- My S3-hosted static website
- My CloudFront CDN distribution
- My Lambda-backed API Gateway endpoint for the contact form
- ACM certificate support for my domain
- GitHub Actions-based CI/CD deployment
- Contains AWS Lambda function for contact form handling:
- `infrastructure/lambda/contact-form/index.js` (handler file)
- `infrastructure/lambda/contact-form/index.test.js` (unit tests)
- `infrastructure/lambda/contact-form/package.json` (runtime dependencies)

### 📋 Workflows

- The deploy-frontend workflow assumes a frontend role and syncs the frontend
  ./src/* directory and it's contents to the S3 bucket

## 🌐 AWS Integration Insights

### ⚙️ AWS Lambda

- Contact form handler is structured as a Lambda function
- Likely deployed via Serverless Framework (pattern inferred)

### 🛠️ API Gateway

- Implied by Lambda function structure (common pattern for HTTP API triggers)

### 📁 S3 (Potential)

- No direct references, but Lambda-based file processing workflows often integrate with S3

## ⚠️ Notes

- No explicit AWS SDK imports found in code files
- No CloudFormation templates or Serverless configuration files detected
- Infrastructure folder suggests AWS deployment pipeline exists but is not visible in current file list
