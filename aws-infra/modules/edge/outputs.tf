output "primary_network_interface_id" {
  description = "The primary network interface ID of the Edge VM instance."
  value       = aws_instance.edge.primary_network_interface_id
}

output "edge_instance_id" {
  description = "The ID of the created Edge VM instance."
  value       = aws_instance.edge.id
}

output "edge_public_ip" {
  description = "The public IP address of the Edge VM. Use this to connect via SSH."
  value       = length(aws_eip_association.eip_assoc) > 0 ? aws_eip_association.eip_assoc[0].public_ip : null
}