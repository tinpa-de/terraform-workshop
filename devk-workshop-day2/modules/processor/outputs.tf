output "function_name" {
  description = "Name der Lambda-Funktion"
  value       = aws_lambda_function.processor.function_name
}

output "function_arn" {
  description = "ARN der Lambda-Funktion"
  value       = aws_lambda_function.processor.arn
}

output "security_group_id" {
  description = "Security Group ID der Lambda - wird für RDS-Ingress benötigt"
  value       = aws_security_group.lambda.id
}

output "log_group_name" {
  description = "CloudWatch Log Group für Debugging"
  value       = aws_cloudwatch_log_group.lambda.name
}
