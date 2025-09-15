variable "project_name" {
  description = "Project name to tag resources"
  type        = string
  default     = ""
}

variable "environment" {
  description = "The environment for which to create resources (e.g., dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "ubuntu_version" {
   description = "Ubuntu version (20.04, 22.04, 24.04)"
     type = string
     default = "22.04" # change here if you want 20.04 or 24.04
}

variable "instance_type" {
  description = "EC2 instance type for the appdb instance"
  type        = string
  default     = "t3.medium" # 2 vCPU / 4GB RAM – enough for Postgres + app
}

variable "private_subnet_id" {
  description = "Private subnet ID for appdb instance"
  type        = string
}

variable "sg_app_id" {
  description = "Security group ID for appdb instance"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile to attach (optional)"
  type        = string
  default     = null
}

variable "ebs_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20 # Docker + Postgres data, OK for lab but increase for prod
}

variable "ebs_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3" # modern default (better performance and cheaper than gp2)
}

variable "delete_on_termination" {
  description = "Whether to delete root volume when instance is terminated"
  type        = bool
  default     = true # ⚠️ If you want DB persistence, set to false
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring (1-min CloudWatch metrics)"
  type        = bool
  default     = false
}

variable "enable_ebs_optimized" {
  description = "Enable EBS optimization for better disk performance"
  type        = bool
  default     = true
}

# App/db parameters
variable "app_image" {
  type        = string
  default     = "nginx:latest"
  description = "App Docker image (placeholder until registry ready)"
}

variable "registry_url" {
  type    = string
  default = ""
}

variable "registry_user" {
  type    = string
  default = ""
}

variable "registry_password" {
  type    = string
  default = ""
}

variable "postgres_db" {
  type    = string
  default = "myapp"
}

variable "postgres_user" {
  type    = string
  default = "myuser"
}

variable "postgres_password" {
  type    = string
  default = "mypassword"
}