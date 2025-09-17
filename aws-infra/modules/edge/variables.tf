variable "common_tags" {
  description = "A map of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "The environment name (e.g., 'dev')."
  type        = string
}

variable "ubuntu_version" {
  description = "The Ubuntu version to use for the Edge VM."
  type        = string
  default     = "22.04"
}

variable "iam_instance_profile_name" {
  description = "The name of the IAM instance profile to attach to the Edge VM."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC to deploy the Edge VM into."
  type        = string
}

variable "public_subnet_id" {
  description = "The ID of the public subnet for the Edge VM."
  type        = string
}

variable "sg_edge_id" {
  description = "The ID of the security group to associate with the Edge VM."
  type        = string
}

variable "instance_type" {
  description = "The EC2 instance type for the Edge VM."
  type        = string
  default     = "t3.micro"
}

variable "admin_user" {
  description = "The username to create on the EC2 instance for admin access."
  type        = string
  default     = "ubuntu"
}

variable "admin_cidrs" {
  description = "A list of IP ranges (CIDR blocks) allowed for SSH and WireGuard access. Allow all for testing purposes."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Testing purposes only, restrict later!
}

variable "key_name" {
  description = "The name of an existing AWS Key Pair to use for SSH access."
  type        = string
}

variable "wireguard_port" {
  description = "The UDP port for the WireGuard VPN server."
  type        = number
  default     = 51820
}

variable "domain_name" {
  description = "The public domain name Caddy will use for HTTPS."
  type        = string
}

variable "backend_servers" {
  description = "A list of private IP:port addresses for the backend application servers."
  type        = list(string)
}