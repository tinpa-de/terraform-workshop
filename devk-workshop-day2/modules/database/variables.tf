variable "project" {
  description = "Projektname"
  type        = string
}

variable "environment" {
  description = "Umgebung"
  type        = string
}

variable "vpc_id" {
  description = "VPC, in der die RDS-Instanz läuft"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets für die DB Subnet Group (mindestens 2 in unterschiedlichen AZs)"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security Groups, die per Ingress auf RDS zugreifen dürfen"
  type        = list(string)
  default     = []
}

variable "db_name" {
  description = "Name der initial angelegten Datenbank"
  type        = string
}

variable "db_username" {
  description = "Master-Username für die Datenbank"
  type        = string
}

variable "db_password" {
  description = "Master-Passwort für die Datenbank (im Workshop OK, sonst Secrets Manager!)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}
