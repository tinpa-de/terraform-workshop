output "endpoint" {
  description = "Vollständiger Endpoint (host:port) der RDS-Instanz"
  value       = aws_db_instance.claims.endpoint
}

output "address" {
  description = "Hostname der RDS-Instanz (ohne Port)"
  value       = aws_db_instance.claims.address
}

output "port" {
  description = "Port der RDS-Instanz"
  value       = aws_db_instance.claims.port
}

output "security_group_id" {
  description = "Security Group ID der RDS-Instanz"
  value       = aws_security_group.rds.id
}

output "db_name" {
  description = "Name der Datenbank"
  value       = aws_db_instance.claims.db_name
}
