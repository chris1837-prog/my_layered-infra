variable "aws_profile" {
  description = "AWS CLI/SSO profile to use when authenticating."
  type        = string
  default     = "layered-qa"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Short project identifier used for tagging."
  type        = string
  default     = "layered"
}

variable "env" {
  description = "Environment name (e.g. dev, qa, prod)."
  type        = string
  default     = "qa"
}

variable "availability_zone" {
  description = "Availability zone that matches the target EC2 instance."
  type        = string
  default     = "eu-central-1a"
}

variable "pg_data_name" {
  description = "Optional override for the Name tag."
  type        = string
  default     = null
}

variable "pg_data_size_gb" {
  description = "Size of the Postgres data volume."
  type        = number
  default     = 100
}

variable "pg_data_volume_type" {
  description = "EBS volume type for the data disk."
  type        = string
  default     = "gp3"
}

variable "pg_data_volume_encrypted" {
  description = "Whether the volume should be encrypted."
  type        = bool
  default     = true
}

variable "pg_data_kms_key_id" {
  description = "KMS key ARN for encryption. Leave null to use the AWS managed key."
  type        = string
  default     = null
}

variable "pg_data_device_name" {
  description = "Device name that the volume should attach as."
  type        = string
  default     = "/dev/xvdb"
}

variable "postgres_host_instance_id" {
  description = "Instance ID of the single Postgres host. Leave null for Launch Template/ASG flows."
  type        = string
  default     = null
}

variable "additional_tags" {
  description = "Extra tags to merge onto the volume."
  type        = map(string)
  default     = {}
}
