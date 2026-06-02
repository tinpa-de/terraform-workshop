variable "project"     { type = string }
variable "environment" { type = string }

variable "source_dir" {
  description = "Pfad zum Lambda-Sourcecode (wird gezippt)"
  type        = string
}

variable "bucket_id" {
  description = "ID des S3-Buckets, der Lambda triggert"
  type        = string
}

variable "bucket_arn" {
  description = "ARN des S3-Buckets, für IAM- und Permissions-Konfiguration"
  type        = string
}

variable "db_host" {
  description = "RDS-Hostname"
  type        = string
}

variable "db_name" {
  description = "Name der Datenbank"
  type        = string
}

variable "db_username" {
  description = "DB-Username"
  type        = string
}

variable "db_password" {
  description = "DB-Passwort"
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
