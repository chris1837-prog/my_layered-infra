variable "ami" {
  description = "AMI ID for the Ubuntu instance"
  type        = string
}

variable "instance_type" {
  description = "Instance type for the edge node"
  type        = string
  default     = "t3.micro"
}

variable "admin_cidrs" {
  description = "List of CIDRs allowed to access the admin services"
  type        = list(string)
  default     = ["95.91.249.11/32"] #my ip
}

variable "domain" {
  description = "Public domain for Caddy reverse proxy"
  type        = string
}

variable "app_private_ip" {
  description = "Private IP address of the app behind edge"
  type        = string
}

variable "app_port" {
  description = "Port the app is listening on"
  type        = number
  default     = 8080
}
variable "key_pair_name" {
  description = "Name of the SSH key pair to use for the EC2 instance"
  type        = string
}
