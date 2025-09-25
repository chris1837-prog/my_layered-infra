// NOTE: The cloudinit_config data source is configured with gzip=true and base64_encode=true.
// The "rendered" attribute is therefore a base64 string of gzip-compressed MIME user-data.
// We expose it as-is and let the test harness decode & gunzip so Terraform doesn't error on
// non-UTF8 binary output when attempting a base64decode inside the plan/apply phase.
output "edge_user_data_raw" {
  description = "Rendered cloud-init user data as delivered to aws_instance (base64; gzip-compressed)."
  value       = data.cloudinit_config.edge.rendered
  sensitive   = true
}
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

output "registry_external_url" {
  description = "The external URL of the Docker registry (proxied by Caddy)."
  value       = var.registry_external_url
}

output "registry_internal_url" {
  description = "The internal URL of the Docker registry (proxied by Caddy)."
  value       = var.registry_internal_url
}

output "registry_tls_mode" {
  description = "TLS mode for external registry host: internal_ca or acme"
  value       = var.enable_acme_external ? "acme" : "internal_ca"
}

output "primary_domain" {
  description = "Primary application domain/host served by Caddy (may be HTTP-only bootstrap or HTTPS depending on flags)."
  value       = var.domain_name
}