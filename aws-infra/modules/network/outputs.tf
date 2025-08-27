# =============================================================================
# Outputs from security_groups.tf
# =============================================================================

output "sg_edge_id" {
  description = "The ID of the Edge security group."
  value       = aws_security_group.edge.id
}

output "sg_app_id" {
  description = "The ID of the App security group."
  value       = aws_security_group.app.id
}