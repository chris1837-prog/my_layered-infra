variable "name" {
  description = "Optional override for the Name tag."
  type        = string
  default     = null
}

variable "project" {
  description = "Short project identifier used for tagging."
  type        = string
}

variable "env" {
  description = "Environment name (e.g. dev, qa, prod)."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone in which to create the EBS volume (must match target instance AZ)."
  type        = string
}

variable "size_gb" {
  description = "Size of the EBS volume in gibibytes."
  type        = number
}

variable "type" {
  description = "EBS volume type (gp3, gp2, io2, etc.)."
  type        = string
  default     = "gp3"
}

variable "encrypted" {
  description = "Whether the EBS volume is encrypted."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "Optional KMS key ARN to use when encrypted = true. Leave null to use the default AWS managed key."
  type        = string
  default     = null
}

variable "iops" {
  description = "Provisioned IOPS for the volume (only valid for certain volume types)."
  type        = number
  default     = null
}

variable "throughput" {
  description = "Provisioned throughput in MiB/s for gp3 volumes."
  type        = number
  default     = null
}

variable "device_name" {
  description = "Device name to expose inside the instance (e.g. /dev/xvdb)."
  type        = string
  default     = "/dev/xvdb"
}

variable "attach_to_instances" {
  description = "Map of logical names to instance IDs that should receive the volume. Leave empty to skip attachment."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Additional tags to merge onto the volume."
  type        = map(string)
  default     = {}
}
