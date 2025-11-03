# variables.tf (Network Module)

# =============================================================================
# Common Variables
# =============================================================================
variable "project_name" {
  description = "Project name to tag resources"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "open_internet_cidr" {
  description = "The CIDR block representing the open internet. Typically 0.0.0.0/0. Made into a variable for rare cases where it might need to be restricted (e.g., in more complex networking scenarios)."
  type        = string
  default     = "0.0.0.0/0"
}

# =============================================================================
# VPC Variables
# =============================================================================
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

# =============================================================================
# Subnet Variables
# =============================================================================
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

# =============================================================================
# Security Group Configuration Variables
# =============================================================================
variable "allowed_admin_cidrs" {
  description = "CIDR blocks from which administrative access (SSH, WireGuard) is allowed."
  type        = list(string)
}

variable "application_port" {
  description = "The port number on which the internal application listens for traffic (e.g., 3000 for a Node.js app)."
  type        = number
  default     = 3000 # A reasonable default, but now it's configurable!
}

# --- Protocol Variables ---
variable "tcp_protocol" {
  description = "The IP protocol name for TCP."
  type        = string
  default     = "tcp"
}

variable "udp_protocol" {
  description = "The IP protocol name for UDP."
  type        = string
  default     = "udp"
}

variable "all_protocols" {
  description = "The value representing all IP protocols."
  type        = string
  default     = "-1"
}

# --- Common Port Variables ---
variable "https_port" {
  description = "The standard port for HTTPS traffic."
  type        = number
  default     = 443
}

variable "http_port" {
  description = "The standard port for HTTP traffic."
  type        = number
  default     = 80
}

variable "ssh_port" {
  description = "The standard port for SSH traffic."
  type        = number
  default     = 22
}

variable "wireguard_port" {
  description = "The standard port for WireGuard VPN traffic."
  type        = number
  default     = 51820
}

variable "loki_port" {
  description = "The standard port for Loki"
  type        = number
  default     = 3100
}