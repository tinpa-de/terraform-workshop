variable "region" {
  default     = "eu-west-1"
  description = "AWS region all resources are created in."
  type        = string
}

variable "project" {
  default     = "nl"
  description = "Project prefix, used as the first segment of every resource name."
  type        = string
}

variable "environment" {
  default     = "dev"
  description = "Environment name, used as the second segment of every resource name."
  type        = string
}

variable "name_suffix" {
  description = "Your first name in lowercase. Keeps your resources apart from everyone else's - set it in terraform.tfvars."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,20}$", var.name_suffix))
    error_message = "name_suffix must be 2-20 lowercase letters or digits, e.g. \"anna\"."
  }
}
