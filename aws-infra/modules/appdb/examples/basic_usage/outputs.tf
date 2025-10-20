output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.network.public_subnet_ids[0]
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.network.private_subnet_ids[0]
}

output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = module.network.igw_id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.network.public_route_table_id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = module.network.private_route_table_id
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = module.network.sg_app_id
}

output "edge_security_group_id" {
  description = "ID of the edge security group"
  value       = module.network.sg_edge_id
}

output "edge_instance_id" {
  description = "ID of the edge instance"
  value       = module.edge.edge_instance_id # Ensure this is defined in edge module
}

output "edge_public_ip" {
  description = "Public IP of the edge instance"
  value       = module.edge.edge_public_ip
}

output "edge_network_interface_id" {
  description = "Primary network interface ID of the edge instance"
  value       = module.edge.primary_network_interface_id
}

output "appdb_instance_id" {
  description = "ID of the appdb instance"
  value       = module.appdb.appdb_instance_id
}

output "appdb_private_ip" {
  description = "Private IP of the appdb instance"
  value       = module.appdb.appdb_private_ip
}

output "eip_allocation_id" {
  description = "Allocation ID of the Elastic IP for the edge instance"
  value       = aws_eip.edge.id
}

output "ec2_instance_connect_endpoint_id" {
  description = "ID of the EC2 Instance Connect Endpoint"
  value       = aws_ec2_instance_connect_endpoint.eic_endpoint.id
}