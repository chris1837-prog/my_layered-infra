locals {
  base_tags = {
    Name    = var.name != null ? var.name : "${var.project}-${var.env}-pg-data"
    Project = var.project
    Env     = var.env
    Role    = "postgres-data"
  }
}

resource "aws_ebs_volume" "data" {
  availability_zone = var.availability_zone
  size              = var.size_gb
  type              = var.type
  encrypted         = var.encrypted
  kms_key_id        = var.kms_key_id

  tags = merge(local.base_tags, var.tags)
}

resource "aws_volume_attachment" "this" {
  count       = var.attach_to_instance_id == null ? 0 : 1
  device_name = var.device_name
  volume_id   = aws_ebs_volume.data.id
  instance_id = var.attach_to_instance_id
}
