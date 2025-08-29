# General variables

variable "project_name" {
  description = "Project name to tag resources"
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
}

# VPC variables
variable "vpc_id" {
  description = "The ID of the VPC where subnets will be created."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "enable_dns_support" {
  description = "Whether DNS support is enabled for the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Whether DNS hostnames are enabled for the VPC"
  type        = bool
  default     = true
}

# IGW variables
variable "igw_id" {
  description = "The ID of the Internet Gateway to attach to the VPC."
  type        = string
}

# Subnet variables
variable "az_configurations" {
  description = "A map of objects defining the configuration for each Availability Zone."
  type = map(object({
    public_subnet_cidr  = string
    private_subnet_cidr = string
  }))
}

variable "allow_map_public_ip_on_launch" {
  description = "Whether to assign public IPs to instances launched in public subnets."
  type        = bool
  default     = true
}