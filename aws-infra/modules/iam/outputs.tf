output "engineer_role_arn" {
  description = "ARN of the engineer IAM role for Terraform remote state access."
  value       = aws_iam_role.engineer.arn
}

output "ec2_instance_profile_name" {
  description = "Instance profile name for AppDB EC2"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}