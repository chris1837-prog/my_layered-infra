########################################
# Outputs (DEV)
########################################

output "budget_dev_name" {
  description = "Budget name in DEV"
  value       = module.budget_dev.budget_name
}

output "budget_dev_topic_arn" {
  description = "SNS Topic ARN for DEV budget alerts"
  value       = module.budget_dev.sns_topic_arn
}

# --- AppDB ---

output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.this.id
}

output "subnet_id" {
  description = "The ID of the created subnet"
  value       = aws_subnet.this.id
}

output "internet_gateway_id" {
  description = "The ID of the created Internet Gateway"
  value       = aws_internet_gateway.public.id
}

output "route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.public.id
}

output "security_group_id" {
  description = "The ID of the application security group"
  value       = aws_security_group.app.id
}