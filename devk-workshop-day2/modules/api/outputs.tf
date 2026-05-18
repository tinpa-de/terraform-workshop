output "api_endpoint" {
  description = "Base URL des API Gateway (z.B. https://xxx.execute-api.eu-central-1.amazonaws.com)"
  value       = aws_apigatewayv2_api.claims.api_endpoint
}

output "function_name" {
  description = "Lambda-Funktionsname für Debugging"
  value       = aws_lambda_function.api.function_name
}

output "security_group_id" {
  description = "Security Group ID der API-Lambda - wird für RDS-Ingress benötigt"
  value       = aws_security_group.lambda.id
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.lambda.name
}
