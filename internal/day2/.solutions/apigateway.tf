# Solution: terraform/apigateway.tf

resource "aws_apigatewayv2_api" "feedback" {
  name          = local.api_name
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.feedback.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_feedback" {
  api_id    = aws_apigatewayv2_api.feedback.id
  route_key = "POST /feedback"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "list_feedback" {
  api_id    = aws_apigatewayv2_api.feedback.id
  route_key = "GET /feedback"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_feedback" {
  api_id    = aws_apigatewayv2_api.feedback.id
  route_key = "GET /feedback/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.feedback.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 100
  }

  tags = local.tags
}

# The console added this for you on Day 1. Without it every call returns 500
# and the function is never invoked.
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.feedback.execution_arn}/*/*"
}
