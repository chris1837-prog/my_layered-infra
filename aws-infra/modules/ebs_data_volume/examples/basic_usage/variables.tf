variable "aws_profile" {
  description = "AWS CLI/SSO profile to use when authenticating (leave null to use the default credential chain)."
  type        = string
  default     = null
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
  description = "Specific AZ to deploy into. Leave null to pick the first available AZ in the chosen region."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the example VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet that hosts the EC2 instance."
  type        = string
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  description = "Instance type for the throwaway host the data volume attaches to."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Optional EC2 key pair to associate with the host for debugging."
  type        = string
  default     = null
}

variable "volume_size_gb" {
  description = "Size of the Postgres data volume."
  type        = number
  default     = 100
}

variable "volume_type" {
  description = "EBS volume type for the data disk."
  type        = string
  default     = "gp3"
}

variable "volume_encrypted" {
  description = "Whether the data volume should be encrypted."
  type        = bool
  default     = true
}

variable "volume_kms_key_id" {
  description = "Optional KMS key ARN to use for encryption. Leave null to use the AWS managed key."
  type        = string
  default     = null
}

variable "volume_iops" {
  description = "Provisioned IOPS for the volume (only required for certain volume types)."
  type        = number
  default     = null
}

variable "volume_throughput" {
  description = "Provisioned throughput (MiB/s) for gp3 volumes."
  type        = number
  default     = null
}

variable "volume_device_name" {
  description = "Device name to expose inside the instance (Nitro instances remap to /dev/nvme*)."
  type        = string
  default     = "/dev/xvdb"
}

variable "additional_tags" {
  description = "Extra tags to merge onto all resources created by the example."
  type        = map(string)
  default     = {}
}
