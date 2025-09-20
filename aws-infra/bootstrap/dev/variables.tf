# bootstrap/dev/variables.tf

variable "aws_region" {
  description = "AWS region where backend and CI/CD role will be created"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name, e.g., dev or prod"
  type        = string
}

variable "common_tags" {
  description = "Map of common tags to apply to all resources (merged with enforced Project/Environment tags)"
  type        = map(string)
  default     = {}
}

variable "github_org" {
  description = "GitHub organization for OIDC trust"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository for OIDC trust"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the CI/CD role"
  type        = string
  default     = "development"
}

variable "restrict_by_tags" {
  description = "If true, limits Terraform permissions to resources with Project/Environment tags"
  type        = bool
  default     = false
}

##################################
# Non-sensitive SSM Parameters
##################################

variable "registry_url" {
  description = "Private Docker registry URL"
  type        = string
}

variable "registry_user" {
  description = "Private Docker registry username"
  type        = string
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
}

variable "app_image_tag" {
  description = "Docker image tag for the application"
  type        = string
}

##################################
# DNS / Route53
##################################

variable "domain_name" {
  description = "The base domain name (e.g., uselayered.com). The hosted zone will be created for {environment}.{domain_name}."
  type        = string
  default     = "uselayered.com"
}

variable "edge_private_ip" {
  description = "Optional private IP address of the edge host (used for DNS records in Route53)"
  type        = string
  default     = null
}
