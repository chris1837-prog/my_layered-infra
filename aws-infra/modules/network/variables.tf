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

variable "wireguard_admin_cidr" {
  description = "CIDR block for WireGuard admin access. Restrict this in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ssh_admin_cidr" {
  description = "CIDR block for SSH admin access. Should be restricted to specific IPs in production."
  type        = string
  default     = "0.0.0.0/0"
}