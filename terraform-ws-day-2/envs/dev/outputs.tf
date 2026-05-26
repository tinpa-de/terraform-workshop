output "s3_bucket" {
  description = "Name des S3-Buckets für Schadensdokumente"
  value       = module.storage.bucket_name
}

# Wird nach TODO B (database) aktiv:
output "rds_endpoint" {
  description = "RDS-Endpoint (für psql, optional)"
  value       = module.database.endpoint
  sensitive   = true
}

# Wird nach TODO C (processor) aktiv:
output "processor_log_group" {
  description = "CloudWatch Log Group der Processor-Lambda - zum Debuggen"
  value       = module.processor.log_group_name
}

# Wird nach TODO D (api) aktiv:
output "api_url" {
  description = "Base URL der Claims-API"
  value       = module.api.api_endpoint
}

output "api_log_group" {
  description = "CloudWatch Log Group der API-Lambda"
  value       = module.api.log_group_name
}
