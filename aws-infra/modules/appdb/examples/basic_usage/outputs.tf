
output "appdb_instance_id" {
  description = "ID of the appdb EC2 instance"
  value       = module.appdb.appdb_instance_id
}

output "appdb_private_ip" {
  description = "Private IP of the appdb EC2 instance"
  value       = module.appdb.appdb_private_ip
}

output "appdb_subnet_id" {
  description = "Subnet ID where appdb is deployed"
  value       = module.appdb.appdb_subnet_id
}

# Helper outputs for manual testing
output "edge_ssh_command" {
  description = "SSH command to connect to the Edge instance"
  value       = "ssh -i ${path.module}/appdb_test_key.pem ubuntu@${aws_instance.edge.public_ip}"
}

output "scp_key_to_edge" {
  description = "Command to copy the AppDB private key to the Edge instance for later SSH"
  value       = "scp -i ${path.module}/appdb_test_key.pem ${path.module}/appdb_test_key.pem ubuntu@${aws_instance.edge.public_ip}:/home/ubuntu/"
}

output "appdb_ssh_command" {
  description = "SSH command (from inside Edge) to connect to the AppDB instance"
  value       = "ssh -i ~/appdb_test_key.pem ubuntu@${aws_instance.appdb.private_ip}"
}

