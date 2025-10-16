output "volume_id" {
  description = "ID of the created EBS volume."
  value       = aws_ebs_volume.data.id
}

output "volume_arn" {
  description = "ARN of the created EBS volume."
  value       = aws_ebs_volume.data.arn
}

output "attachment_id" {
  description = "ID of the attachment if the volume is attached to an instance, otherwise null."
  value       = try(aws_volume_attachment.this[0].id, null)
}
