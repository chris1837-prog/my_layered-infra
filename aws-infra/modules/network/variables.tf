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

variable "open_internet_cidr" {
  description = "The CIDR block representing the open internet. Typically 0.0.0.0/0. Made into a variable for rare cases where it might need to be restricted (e.g., in more complex networking scenarios)."
  type        = string
  default     = "0.0.0.0/0"
}