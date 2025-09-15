output "edge_instance_id" {
  description = "The ID of the created Edge VM instance."
  value       = aws_instance.edge.id
}

output "edge_public_ip" {
  description = "The public IP address of the Edge VM. Use this to connect via SSH."
  value       = aws_eip.edge.public_ip
}

output "edge_private_key_path" {
  description = "Path to the generated private SSH key for the Edge VM. Use this to connect as the admin user."
  value       = local_file.edge_private_key.filename
}