module "pg_data_volume" {
  source = "../../../modules/ebs_data_volume"

  name                  = var.pg_data_name
  project               = var.project
  env                   = var.env
  availability_zone     = var.availability_zone
  size_gb               = var.pg_data_size_gb
  type                  = var.pg_data_volume_type
  encrypted             = var.pg_data_volume_encrypted
  kms_key_id            = var.pg_data_kms_key_id
  device_name           = var.pg_data_device_name
  attach_to_instance_id = var.postgres_host_instance_id
  tags                  = var.additional_tags
}
