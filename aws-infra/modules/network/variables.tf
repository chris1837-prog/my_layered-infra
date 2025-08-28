variable "project_name" {
  description = "Project name to tag resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
}

variable "vpc_id" {
  description = "ID of the VPC to attach the Internet Gateway"
  type        = string
}


