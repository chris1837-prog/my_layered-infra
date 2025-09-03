# =============================================================================
# examples/private_egress_via_edge/outputs.tf
# Outputs for NAT instance testing
# =============================================================================

output "edge_instance_id" {
  value = aws_instance.test_edge_instance.id
}

output "edge_public_ip" {
  value = aws_instance.test_edge_instance.public_ip
}

output "edge_primary_network_interface_id" {
  value = aws_instance.test_edge_instance.primary_network_interface_id
}

output "private_test_instance_id" {
  value = aws_instance.test_appdb_instance.id
}

output "private_test_private_ip" {
  value = aws_instance.test_appdb_instance.private_ip
}

# Optional but helpful
output "private_route_table_id" {
  value = module.network.private_route_table_id
}

output "vpc_cidr" {
  value = local.vpc_cidr
}

output "ssh_private_key_file" {
  value       = "${path.module}/network_test_key.pem"
  description = "Path to the generated private key for SSH access to test instances"
}

output "ssh_key_name" {
  value       = aws_key_pair.this.key_name
  description = "Name of the generated AWS Key Pair"
}