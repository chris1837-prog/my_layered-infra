# bootstrap/dev/main.tf

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# Call remote_backend module
module "remote_backend" {
  source       = "../../modules/remote_backend"
  project_name = var.project_name
  environment  = var.environment
  common_tags  = var.common_tags
}

# GitHub Actions Role for Terraform CI/CD
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-terraform-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
          }
        }
      }
    ]
  })

  # Attach the permission boundary
  permissions_boundary = aws_iam_policy.github_actions_boundary.arn

  tags = merge(
    { Name = "${var.project_name}-${var.environment}-terraform-github-actions-role" },
    var.common_tags
  )
}

# Optional IAM policy restriction by tags
locals {
  tag_conditions = var.restrict_by_tags ? {
    "StringEquals" = {
      "aws:RequestTag/Project"     = var.project_name
      "aws:RequestTag/Environment" = var.environment
    }
  } : {}
}

# Create a managed policy for GitHub Actions role (broad for agility in dev)
resource "aws_iam_policy" "github_actions_policy" {
  name        = "${var.project_name}-${var.environment}-terraform-github-actions-policy"
  description = "Permissions for GitHub Actions to execute Terraform commands"
  path        = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "*"
        Resource  = "*"
        Condition = local.tag_conditions
      }
    ]
  })
  tags = merge(
    { Name = "${var.project_name}-${var.environment}-terraform-github-actions-policy" },
    var.common_tags
  )
}

# Attach the managed policy to the role
resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

# Permission boundary to prevent privilege escalation
resource "aws_iam_policy" "github_actions_boundary" {
  name        = "${var.project_name}-${var.environment}-github-actions-boundary"
  description = "Permission boundary to prevent IAM user/key creation and direct user policy management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:DeleteUser",
          "iam:AttachUserPolicy",
          "iam:PutUserPolicy",
          "iam:CreateAccessKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# Generate backend.tf
resource "local_file" "backend_config" {
  filename = "${path.module}/../../environments/${var.environment}/backend.tf"
  content  = <<EOT
terraform {
  backend "s3" {
    bucket         = "${module.remote_backend.tf_state_bucket_name}"
    dynamodb_table = "${module.remote_backend.tf_state_lock_table}"
    key            = "terraform.tfstate"
    region         = "${var.aws_region}"
  }
}
EOT
}

# Generate bootstrap_outputs.json
resource "local_file" "bootstrap_outputs" {
  filename = "${path.module}/../../environments/${var.environment}/bootstrap_outputs.json"
  content = jsonencode({
    tf_state_bucket_name    = module.remote_backend.tf_state_bucket_name
    tf_state_lock_table     = module.remote_backend.tf_state_lock_table
    github_actions_role_arn = aws_iam_role.github_actions.arn
  })
}

