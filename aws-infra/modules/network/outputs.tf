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