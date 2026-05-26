output "s3_bucket" {
  description = "Name des S3-Buckets für Schadensdokumente"
  value       = module.storage.bucket_name
}

# Wird nach TODO B (database) aktiv:
# output "rds_endpoint" {
#   description = "RDS-Endpoint (für psql, optional)"
#   value       = module.database.endpoint
#   sensitive   = true
# }

# Wird nach TODO C/D (processor + api) aktiv:
# output "api_url" {
#   description = "Base URL der Claims-API"
#   value       = module.api.api_endpoint
# }

# output "processor_log_group" {
#   description = "CloudWatch Log Group der Processor-Lambda - zum Debuggen"
#   value       = module.processor.log_group_name
# }

# output "api_log_group" {
#   description = "CloudWatch Log Group der API-Lambda"
#   value       = module.api.log_group_name
# }

# output "test_commands" {
#   description = "Beispiel-Kommandos zum Testen"
#   value = <<-EOT
#
#     # 1. Upload-Test (triggert die Processor-Lambda):
#     echo "Test claim" > /tmp/test.txt
#     aws s3 cp /tmp/test.txt s3://${module.storage.bucket_name}/policies/POL-123/test.txt
#
#     # 2. Logs der Processor-Lambda anschauen:
#     aws logs tail ${module.processor.log_group_name} --follow
#
#     # 3. Claim per API anlegen:
#     curl -X POST ${module.api.api_endpoint}/claims \
#       -H "Content-Type: application/json" \
#       -d '{"policy_number":"POL-123","claim_type":"motor","description":"Parkschaden"}'
#
#     # 4. Claims auflisten:
#     curl ${module.api.api_endpoint}/claims
#
#   EOT
# }
