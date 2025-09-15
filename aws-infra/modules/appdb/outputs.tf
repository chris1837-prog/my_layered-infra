output "appdb_instance_id" {
  value       = aws_instance.app.id
  description = "ID of the appdb EC2 instance"
}

output "appdb_private_ip" {
  value       = aws_instance.app.private_ip
  description = "Private IP of the appdb EC2 instance"
}

output "appdb_subnet_id" {
  value       = aws_instance.app.subnet_id
  description = "Subnet ID where appdb is deployed"
}
