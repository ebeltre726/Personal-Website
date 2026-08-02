variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Primary domain name for the site"
  type        = string
  default     = "ebeltre.com"
}

variable "hostinger_zone_id" {
  description = "Route53 hosted zone ID for the domain (Hostinger-managed DNS zone)"
  type        = string
  default     = ""
}

variable "emailjs_service_id" {
  description = "EmailJS service ID"
  type        = string
  default     = ""
}

variable "emailjs_template_id" {
  description = "EmailJS template ID"
  type        = string
  default     = ""
}

variable "emailjs_public_key" {
  description = "EmailJS public key"
  type        = string
  default     = ""
}

variable "emailjs_private_key" {
  description = "EmailJS private key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "allowed_origin" {
  description = "Allowed origins for Lambda CORS responses"
  type        = string
  default     = "https://ebeltre.com,https://www.ebeltre.com"
}

variable "mime_types" {
  description = "Common MIME types for static assets"
  type        = map(string)
  default = {
    html = "text/html"
    htm  = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    svg  = "image/svg+xml"
    ico  = "image/x-icon"
    txt  = "text/plain"
    map  = "application/json"
  }
}
