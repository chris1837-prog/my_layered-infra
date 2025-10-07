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

variable "device_name" {
  description = "Device name to expose inside the instance (e.g. /dev/xvdb)."
  type        = string
  default     = "/dev/xvdb"
}

variable "attach_to_instance_id" {
  description = "Instance ID to attach the volume to. Leave null to skip attachment (for Launch Template/ASG workflows)."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to merge onto the volume."
  type        = map(string)
  default     = {}
}
