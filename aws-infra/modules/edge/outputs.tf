output "edge_public_ip" {
  description = "Public IP address of the edge instance"
  value       = aws_eip.edge_eip.public_ip
}

output "edge_public_dns" {
  description = "Public DNS of the edge instance"
  value       = aws_instance.edge.public_dns
}

output "edge_private_ip" {
  description = "Private IP address of the edge instance"
  value       = aws_instance.edge.private_ip
}

output "edge_instance_id" {
  description = "Instance ID of the edge instance"
  value       = aws_instance.edge.id
}

output "security_group_id" {
  description = "Security group ID for the edge instance"
  value       = aws_security_group.edge_sg.id
}

output "wireguard_port" {
  description = "WireGuard VPN port"
  value       = var.wireguard_port
}

output "wireguard_network" {
  description = "WireGuard VPN network"
  value       = var.wireguard_network
}

output "wireguard_endpoint" {
  description = "WireGuard VPN endpoint (public IP + port)"
  value       = "${aws_eip.edge_eip.public_ip}:${var.wireguard_port}"
}

output "admin_onboarding_command" {
  description = "Command to access admin onboarding documentation"
  value       = "ssh -i ${var.key_pair_name}.pem ${var.admin_user}@${aws_eip.edge_eip.public_ip} 'cat /opt/hardened-edge/docs/ADMIN_ONBOARDING.md'"
}

output "caddy_dashboard_url" {
  description = "Caddy reverse proxy admin dashboard URL (internal)"
  value       = "http://${aws_instance.edge.private_ip}:2019"
}