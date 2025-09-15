variable "vpc_id" {
  description = "The ID of the VPC to deploy into. Replace with your actual VPC ID."
  type        = string
  default    = "vpc-01f65b7c69d2af66f" # Default vpc for testing in eu-central-1
}

variable "aws_profile" {
  description = "The AWS profile to use. Replace with your actual profile."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy into. Replace with your actual region."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type for the Edge VM."
  type        = string
}

variable "public_subnet_id" {
  description = "The ID of the public subnet to deploy into. Replace with your actual subnet ID."
  type        = string
  default     = "subnet-0f8b78e529ceeec3b" # Default public subnet for testing in eu-central-1
}

variable "admin_cidrs" {
  description = "A list of IP ranges to allow SSH and WireGuard access from."
  type        = list(string)
}
variable "domain_name" {
  description = "The public domain name Caddy will use for HTTPS."
  type        = string
}

variable "backend_servers" {
  description = "A list of private IP:port addresses for the backend application servers."
  type        = list(string)
}