variable "registry_user" {
  description = "Username for the Docker registry."
  type        = string
}

variable "registry_password" {
  description = "Password for the Docker registry."
  type        = string
  sensitive   = true
}

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

variable "registry_external_url" {
  description = "External registry URL (e.g., https://registry.example.com)."
  type        = string
  validation {
    condition     = startswith(var.registry_external_url, "https://")
    error_message = "registry_external_url must start with https://"
  }
}

variable "registry_internal_url" {
  description = "Internal registry URL (e.g., https://registry.internal.example.com)."
  type        = string
  validation {
    condition     = startswith(var.registry_internal_url, "https://")
    error_message = "registry_internal_url must start with https://"
  }
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

variable "eip_allocation_id" {
  description = "The allocation ID of an existing Elastic IP to associate with the Edge instance."
  type        = string
  default     = null # Make it optional if you have fallback logic for dev, but required for staging/prod
}

variable "enable_eip_association" {
  description = "Whether to associate the provided Elastic IP with the Edge instance. Controls resource count to avoid unknown values at plan time."
  type        = bool
  default     = false
}

variable "edge_private_ip" {
  description = "The private IP address to assign to the Edge instance."
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
  validation {
    condition     = length(var.admin_cidrs) > 0
    error_message = "admin_cidrs must have at least one CIDR entry."
  }
}

variable "admin_ssh_keys" {
  description = "A list of public SSH keys to add to the admin user's authorized_keys."
  type        = list(string)
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

variable "enable_domain_tls" {
  description = "If true, serve the primary domain over HTTPS. If false, start in HTTP-only bootstrap mode (no TLS) on port 80."
  type        = bool
  default     = true
}

variable "enable_domain_acme" {
  description = "If true (and enable_domain_tls=true), obtain a public ACME certificate for the primary domain using Caddy's automatic HTTPS. If false, use Caddy internal CA (self-signed). Ignored when enable_domain_tls=false."
  type        = bool
  default     = true
}

variable "backend_servers" {
  description = "A list of private IP:port addresses for the backend application servers."
  type        = list(string)
  validation {
    condition     = length(var.backend_servers) > 0
    error_message = "backend_servers must contain at least one backend (ip:port)."
  }
}

variable "enable_wireguard" {
  description = "Whether to install and configure the WireGuard VPN server. Set to false to skip WireGuard provisioning."
  type        = bool
  default     = true
}

variable "enable_acme_external" {
  description = "If true, Caddy will obtain a public certificate (ACME) for the external registry domain instead of using the internal CA. Requires the external domain to resolve publicly and ports 80/443 reachable."
  type        = bool
  default     = false
}

variable "acme_email" {
  description = "Contact email for ACME (Let's Encrypt/ZeroSSL). Recommended when enable_acme_external is true."
  type        = string
  default     = ""
  validation {
    condition     = var.enable_acme_external ? length(trimspace(var.acme_email)) > 0 : true
    error_message = "acme_email must be non-empty when enable_acme_external is true."
  }
}

variable "promtail_version" {
  description = "Promtail binary version to install on the edge VM (e.g., 2.9.4)."
  type        = string
  default     = "2.9.4"
}

variable "app_private_ip" {
  type = string
}