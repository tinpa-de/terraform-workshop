variable "project"     { type = string }
variable "environment" { type = string }

variable "source_dir" {
  description = "Pfad zum Lambda-Sourcecode"
  type        = string
}

variable "bucket_name" { type = string }
variable "bucket_arn"  { type = string }

variable "db_host"     { type = string }
variable "db_name"     { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}

variable "layers" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
