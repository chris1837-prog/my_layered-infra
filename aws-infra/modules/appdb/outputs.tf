output "appdb_instance_id" {
  description = "ID of the appdb EC2 instance"
  value       = aws_instance.app.id
}

output "appdb_private_ip" {
  description = "Private IP of the appdb EC2 instance"
  value       = aws_instance.app.private_ip
}

output "appdb_subnet_id" {
  description = "Subnet ID where appdb is deployed"
  value       = aws_instance.app.subnet_id
}
