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
  description = "Map of common tags to apply to all resources"
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
