output "endpoint" {
  description = "Vollständiger Endpoint (host:port) der RDS-Instanz"
  value       = aws_db_instance.db_instance.endpoint
}

output "address" {
  description = "Hostname der RDS-Instanz (ohne Port)"
  value       = aws_db_instance.db_instance.address
}

output "port" {
  description = "Port der RDS-Instanz"
  value       = aws_db_instance.db_instance.port
}


output "db_name" {
  description = "Name der Datenbank"
  value       = aws_db_instance.db_instance.db_name
}
