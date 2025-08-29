output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}
output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "A list of the public subnet IDs."
  # Correct: Convert map to a list with values() before getting the IDs
  value       = values(aws_subnet.public)[*].id
}

output "private_subnet_ids" {
  description = "A list of the private subnet IDs."
  # Correct: Convert map to a list with values() before getting the IDs
  value       = values(aws_subnet.private)[*].id
}