# Outputs for the simplified development environment

output "vpc_id" {
  description = "ID of the test VPC"
  value       = aws_vpc.test_vpc.id
}

output "subnet_id" {
  description = "ID of the test subnet"
  value       = aws_subnet.test_subnet.id
}

