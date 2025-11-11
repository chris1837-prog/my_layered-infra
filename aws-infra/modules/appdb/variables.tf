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
  type        = string
  default     = "22.04" # change here if you want 20.04 or 24.04
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

variable "appdb_instance_profile_name" {
  description = "IAM instance profile to attach"
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
  default     = false # DB is persistent
}

variable "db_volume_size" {
  description = "Size of the dedicated Postgres data volume in GB"
  type        = number
  default     = 20
}

variable "db_volume_type" {
  description = "EBS volume type for Postgres data (gp3, gp2, io1, etc.)"
  type        = string
  default     = "gp3"
}

variable "db_volume_iops" {
  description = "Provisioned IOPS for the Postgres data volume (required for certain volume types)"
  type        = number
  default     = null
}

variable "db_volume_throughput" {
  description = "Provisioned throughput (MiB/s) for gp3 volumes"
  type        = number
  default     = null
}

variable "db_volume_encrypted" {
  description = "Whether the Postgres data volume should be encrypted"
  type        = bool
  default     = true
}

variable "db_volume_kms_key_id" {
  description = "Optional KMS key ID to use for Postgres data volume encryption"
  type        = string
  default     = null
}

variable "db_volume_device_name" {
  description = "Linux device name to attach the Postgres data volume as (Nitro instances remap to /dev/nvme*)"
  type        = string
  default     = "/dev/xvdh"
}

variable "db_volume_mount_path" {
  description = "Filesystem path where the Postgres data volume should be mounted"
  type        = string
  default     = "/var/lib/postgresql/data"
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

variable "ssm_app_image_name_path" {
  description = "SSM parameter path for application image name (e.g., 'myorg/myapp' or 'myapp')"
  type        = string
}

variable "ssm_internal_registry_url_path" {
  description = "SSM parameter path for the internal registry URL"
  type        = string
}

variable "ssm_app_image_tag_path" {
  description = "SSM parameter path for the application image tag"
  type        = string
}

variable "ssm_postgres_user_path" {
  description = "SSM parameter path for the Postgres username"
  type        = string
}

variable "ssm_postgres_password_path" {
  description = "SSM parameter path for the Postgres password"
  type        = string
}

variable "ssm_postgres_db_path" {
  description = "SSM parameter path for the Postgres database name"
  type        = string
}

variable "ssm_registry_user_path" {
  description = "SSM parameter path for the registry username (optional, only used if login is required)"
  type        = string
}

variable "ssm_registry_password_path" {
  description = "SSM parameter path for the registry password (optional, only used if login is required)"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

variable "docker_compose_content" {
  description = "Content of the Docker Compose file"
  type        = string
}

variable "db_volume_id" {
  description = "ID of the EBS volume for the database (if applicable)"
  type        = string
}

variable "promtail_version" {
  description = "Version of Promtail to install"
  type        = string
  default     = "2.9.4"
}

variable "promtail_config_content" {
  description = "Content of the Promtail configuration file"
  type        = string
}

variable "edge_private_ip" {
  description = "The private IP of the Edge VM for the Loki endpoint."
  type        = string
  default     = null
}

variable "node_exporter_version" {
  description = "The version of Node Exporter to install."
  type        = string
  default     = "1.8.1"
}

variable "app_private_ip" {
  description = "The static private IP to assign to the AppDB instance."
  type        = string
}
