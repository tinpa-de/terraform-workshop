# =============================================================================
# Part 3: The front door - API Gateway v2 (HTTP API)
# =============================================================================
#
# Goal:
#   Put the three routes from Day 1 in front of your Lambda.
#
# Requirements:
#   1. aws_apigatewayv2_api        - the API itself, protocol_type "HTTP".
#   2. aws_apigatewayv2_integration - connects the API to the Lambda.
#                                     integration_type "AWS_PROXY".
#   3. aws_apigatewayv2_route      - one per route:
#                                     POST /feedback
#                                     GET  /feedback
#                                     GET  /feedback/{id}
#   4. aws_apigatewayv2_stage      - given below, uncomment it with the rest.
#   5. aws_lambda_permission       - lets API Gateway invoke the function.
#
# On Day 1 the console created requirement 5 for you, silently, when you
# attached the integration. Here nothing is silent: without that permission
# every call returns 500 and the Lambda is never even reached.
#
# Terraform documentation:
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission
#
# Tip:
#   A route's target is the string "integrations/<integration id>". Terraform
#   can build that for you - you do not need to know the id up front.

# TODO 3.1 - the API
#
# resource "aws_apigatewayv2_api" "feedback" {
#   ...
# }

# TODO 3.2 - the Lambda integration
#
# resource "aws_apigatewayv2_integration" "lambda" {
#   ...
# }

# TODO 3.3 - the three routes
#
# resource "aws_apigatewayv2_route" "create_feedback" {
#   ...
# }
#
# resource "aws_apigatewayv2_route" "list_feedback" {
#   ...
# }
#
# resource "aws_apigatewayv2_route" "get_feedback" {
#   ...
# }

# TODO 3.4 - the stage.
# Given as-is, nothing to work out here. Uncomment it together with TODO 3.1,
# otherwise it references an API that does not exist yet.
#
# resource "aws_apigatewayv2_stage" "default" {
#   api_id      = aws_apigatewayv2_api.feedback.id
#   name        = "$default"
#   auto_deploy = true
#
#   default_route_settings {
#     throttling_burst_limit = 50
#     throttling_rate_limit  = 100
#   }
#
#   tags = local.tags
# }

# TODO 3.5 - allow API Gateway to invoke the Lambda
#
# resource "aws_lambda_permission" "apigw" {
#   ...
# }
