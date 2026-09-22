# Outputs are the values Terraform prints after an apply, and that you can
# read back later with `terraform output`. Use them instead of copying IDs
# and URLs out of the console by hand.

# Live from the start - no resources needed, these come straight from locals.
output "resource_names" {
  description = "The names this configuration will give your resources."
  value = {
    bucket   = local.bucket_name
    function = local.function_name
    api      = local.api_name
  }
}

# --- Uncomment after Part 1 (S3) ---------------------------------------------

# output "bucket_name" {
#   description = "Name of the feedback bucket."
#   value       = aws_s3_bucket.feedback.bucket
# }

# --- Uncomment after Part 2 (Lambda) -----------------------------------------

# output "log_group_name" {
#   description = "CloudWatch log group of the API Lambda - handy for `aws logs tail`."
#   value       = aws_cloudwatch_log_group.api.name
# }

# --- Uncomment after Part 3 (API Gateway) ------------------------------------

# output "api_url" {
#   description = "Base URL of the HTTP API. Append /feedback to call it."
#   value       = aws_apigatewayv2_stage.default.invoke_url
# }
