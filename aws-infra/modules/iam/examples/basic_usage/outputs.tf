output "engineer_role_arn" {
  description = "ARN of the engineer IAM role for Terraform remote state access."
  value       = module.iam.engineer_role_arn
}

output "ec2_instance_profile_name" {
  description = "Instance profile name for AppDB EC2"
  value       = module.iam.ec2_instance_profile_name
}