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

# =============================================================================
# Security Group Configuration Variables
# =============================================================================

variable "allowed_admin_cidr" {
  description = "The CIDR block from which administrative access (SSH, WireGuard) is allowed. Should be restricted to trusted IPs (e.g., your office/home IP)."
  type        = string
  # Sensitive: No default value is best practice, forcing user to set it explicitly.
}

variable "application_port" {
  description = "The port number on which the internal application listens for traffic (e.g., 3000 for a Node.js app)."
  type        = number
  default     = 3000 # A reasonable default, but now it's configurable!
}

variable "open_internet_cidr" {
  description = "The CIDR block representing the open internet. Typically 0.0.0.0/0. Made into a variable for rare cases where it might need to be restricted (e.g., in more complex networking scenarios)."
  type        = string
  default     = "0.0.0.0/0"
}

# --- Protocol Variables (Optional but highly recommended for clarity) ---
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

# --- Common Port Variables (Optional but good practice) ---
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
