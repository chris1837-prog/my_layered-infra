output "edge_public_ip" {
  description = "Public IP of the edge node"
  value       = aws_instance.edge.public_ip
}

output "edge_private_ip" {
  description = "Private IP of the edge node"
  value       = aws_instance.edge.private_ip
}
