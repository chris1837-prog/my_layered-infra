# Gets the current AWS region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# IAM policy document for Terraform remote state access (S3 + DynamoDB) in memory creation
data "aws_iam_policy_document" "remote_state_access" {
  statement { # S3
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.tf_state_bucket}",
      "arn:aws:s3:::${var.tf_state_bucket}/*"
    ]
  }
  statement { # DynamoDB
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:UpdateItem"
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.lock_table}"
    ]
  }
}

# IAM policy for Terraform remote state access (S3 + DynamoDB) in aws directly
resource "aws_iam_policy" "remote_state_access" {
  name        = "terraform-remote-state-access"
  description = "IAM policy for Terraform remote state access (S3 + DynamoDB)"
  policy      = data.aws_iam_policy_document.remote_state_access.json
}



# IAM trust policy document for the engineer role
data "aws_iam_policy_document" "engineer_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::694816839566:root"] # Needs to be highly tightened in future Tasks.
    }
  }
}

# Engineer IAM role for Terraform remote state access
resource "aws_iam_role" "engineer" {
  name               = var.engineer_role_name
  assume_role_policy = data.aws_iam_policy_document.engineer_trust_policy.json
}

# Attaches the remote state access policy to the engineer role
resource "aws_iam_role_policy_attachment" "engineer_remote_state" {
  role       = aws_iam_role.engineer.name
  policy_arn = aws_iam_policy.remote_state_access.arn
}
