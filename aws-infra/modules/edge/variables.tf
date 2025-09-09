variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_id" {
  description = "VPC ID where the edge instance will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the edge instance will be deployed"
  type        = string
}


variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "admin_cidrs" {
  description = "CIDR blocks allowed for SSH and WireGuard access"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "wireguard_port" {
  description = "UDP port for WireGuard VPN"
  type        = number
  default     = 51820
}

variable "wireguard_network" {
  description = "WireGuard VPN network CIDR"
  type        = string
  default     = "10.200.0.0/24"
}

variable "domain_name" {
  description = "Domain name for Caddy reverse proxy"
  type        = string
  default     = "example.com"
}

variable "backend_servers" {
  description = "Backend servers for reverse proxy"
  type        = list(string)
  default     = ["127.0.0.1:8080"]
}


variable "admin_user" {
  description = "Admin username for SSH access"
  type        = string

}

variable "admin_ssh_keys" {
  description = "List of SSH public keys for admin access"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.admin_ssh_keys) > 0
    error_message = "At least one SSH public key must be provided."
  }
}