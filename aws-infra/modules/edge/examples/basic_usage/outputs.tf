output "edge_public_ip" {
  description = "The public IP of the Edge VM. Use this for SSH and DNS."
  value       = module.edge.edge_public_ip
}

output "edge_private_key_path" {
  description = "Path to the generated private SSH key for the Edge VM. Use this to connect as the admin user."
  value       = local_file.edge_private_key.filename
}

output "edge_instance_id" {
  description = "The ID of the created Edge VM instance."
  value       = module.edge.edge_instance_id
}

output "registry_external_url" {
  description = "The external URL of the Docker registry (proxied by Caddy)."
  value       = "https://${module.edge.registry_external_domain}"
}

output "registry_internal_url" {
  description = "The internal URL of the Docker registry (proxied by Caddy)."
  value       = "https://${module.edge.registry_internal_domain}"
}