variable "project" {
  description = "Projektname, wird als Präfix für Ressourcennamen verwendet"
  type        = string
}

variable "environment" {
  description = "Umgebung (z.B. dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Tags, die auf alle Ressourcen angewendet werden"
  type        = map(string)
  default     = {}
}
