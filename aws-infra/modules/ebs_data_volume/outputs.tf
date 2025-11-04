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

# --- EBS Volume Outputs ---
output "db_volume_id" {
  description = "ID of the created EBS data volume"
  value       = aws_ebs_volume.data.id
}

output "db_volume_az" {
  description = "Availability Zone of the EBS volume"
  value       = aws_ebs_volume.data.availability_zone
}

output "db_volume_size" {
  description = "Size of the EBS volume in GiB"
  value       = aws_ebs_volume.data.size
}

output "db_volume_type" {
  description = "Type of the EBS volume (gp3, io1, etc.)"
  value       = aws_ebs_volume.data.type
}

output "db_volume_device" {
  description = "Device name used for attachment (e.g. /dev/xvdb)"
  value       = var.device_name
}

output "db_volume_instance_ids" {
  description = "List of EC2 instance IDs this volume is attached to"
  value       = [for k, v in aws_volume_attachment.this : v.instance_id]
}
