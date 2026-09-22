# Solution: terraform/outputs.tf (everything uncommented)

output "resource_names" {
  description = "The names this configuration will give your resources."
  value = {
    bucket   = local.bucket_name
    function = local.function_name
    api      = local.api_name
  }
}

output "bucket_name" {
  description = "Name of the feedback bucket."
  value       = aws_s3_bucket.feedback.bucket
}

output "log_group_name" {
  description = "CloudWatch log group of the API Lambda - handy for `aws logs tail`."
  value       = aws_cloudwatch_log_group.api.name
}

output "api_url" {
  description = "Base URL of the HTTP API. Append /feedback to call it."
  value       = aws_apigatewayv2_stage.default.invoke_url
}
