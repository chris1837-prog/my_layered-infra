# variables.tf (Network Module)

variable "project_name" {
  description = "The name of the project, used for resource naming and tagging."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to be applied to all resources."
  type        = map(string)
  default     = {}
}

variable "allowed_admin_cidr" {
  description = "CIDR block for WireGuard/SSH admin access. Restrict this in production."
  type        = string
  default     = "0.0.0.0/0"
}
