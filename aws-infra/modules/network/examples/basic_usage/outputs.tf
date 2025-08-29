# =============================================================================
# examples/basic/outputs.tf
# Outputs to display after running terraform plan/apply for testing and validation.
# =============================================================================

output "vpc_id" {
  description = "The ID of the created VPC."
  value       = module.network.vpc_id
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = module.network.igw_id
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = module.network.private_subnet_ids
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = module.network.public_route_table_id
}

output "private_route_table_id" {
  description = "The ID of the private route table."
  value       = module.network.private_route_table_id
}

output "sg_edge_id" {
  description = "The ID of the Security Group for the Edge instance."
  value       = module.network.sg_edge_id
}

output "sg_app_id" {
  description = "The ID of the Security Group for the App instance."
  value       = module.network.sg_app_id
}