output "edge_public_ip" {
  description = "The public IP of the Edge VM. Use this for SSH and DNS."
  value       = module.edge.edge_public_ip
}