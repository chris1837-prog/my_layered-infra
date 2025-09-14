output "engineer_role_arn" {
  description = "ARN of the engineer IAM role for Terraform remote state access."
  value       = module.iam.engineer_role_arn
}
