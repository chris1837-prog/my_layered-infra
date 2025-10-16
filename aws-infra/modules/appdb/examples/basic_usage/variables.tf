# Variable definitions for the simplified development environment

variable "aws_region" {
  description = "AWS region for the infrastructure"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the test VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_block" {
  description = "CIDR block for the test subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_block" {
  description = "CIDR block for the test subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "environment" {
  description = "Environment name (e.g., development)"
  type        = string
  default     = "development"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
  default     = "default-layered-key"
}

variable "docker_compose_content" {
  description = "Content of the Docker Compose file"
  type        = string
}

variable "db_volume_id" {
  description = "ID of the EBS volume for the database (if applicable)"
  type        = string
}