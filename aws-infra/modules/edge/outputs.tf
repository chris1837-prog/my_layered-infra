output "edge_private_ip" {
  description = "The private IP address of the Edge VM. Use this for internal DNS and registry A record."
  value       = aws_instance.edge.private_ip
}

output "registry_domain" {
  description = "The FQDN of the Docker registry."
  value       = var.registry_domain
}

output "registry_zone_id" {
  description = "The Route 53 private hosted zone ID for the registry."
  value       = aws_route53_zone.registry_private.zone_id
}
output "edge_instance_id" {
  description = "The ID of the created Edge VM instance."
  value       = aws_instance.edge.id
}

output "edge_public_ip" {
  description = "The public IP address of the Edge VM. Use this to connect via SSH."
  value       = aws_eip.edge.public_ip
}