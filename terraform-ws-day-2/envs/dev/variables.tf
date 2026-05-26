variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Projektname"
  type        = string
  default     = "devk"
}

variable "environment" {
  description = "Umgebung"
  type        = string
  default     = "dev"
}

variable "db_username" {
  description = "Master-Username für RDS"
  type        = string
  default     = "claims_admin"
}

variable "db_password" {
  description = "Master-Passwort für RDS - per tfvars oder TF_VAR_db_password setzen"
  type        = string
  sensitive   = true
}
