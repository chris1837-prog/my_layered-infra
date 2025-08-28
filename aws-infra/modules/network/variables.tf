variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "common_tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
}

variable "vpc_id" {
  description = "The ID of the VPC."
  type        = string
}

variable "igw_id" {
  description = "The ID of the Internet Gateway."
  type        = string
}

variable "public_subnets" {
  description = "A map of public subnets."
  type        = map(object({ id = string }))
}

variable "private_subnets" {
  description = "A map of private subnets."
  type        = map(object({ id = string }))
}