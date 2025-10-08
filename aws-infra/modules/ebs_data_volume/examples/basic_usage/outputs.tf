output "pg_data_volume_id" {
  description = "ID of the Postgres data EBS volume."
  value       = module.pg_data_volume.volume_id
}

output "pg_data_volume_arn" {
  description = "ARN of the Postgres data EBS volume."
  value       = module.pg_data_volume.volume_arn
}

output "host_instance_id" {
  description = "ID of the throwaway EC2 host used to exercise the module."
  value       = aws_instance.host.id
}
