data "archive_file" "api_lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/api.zip"
}

# IAM-Rolle wurde vorab vom Admin angelegt – hier wird sie per Name nachgeschlagen.
data "aws_iam_role" "api" {
  name = "${var.project}-${var.environment}-api-role"
}

# TODO 1: Lambda-Funktion provisionieren
# Das Muster kennt ihr aus dem Processor-Modul – schaut dort nach.
# Unterschiede: function_name endet auf "claims-api-jasper", timeout = 15, memory_size = 256.
# Zusätzliche Env-Variable: BUCKET_NAME = var.bucket_name
# IAM-Rolle: data.aws_iam_role.api.arn
#
# WICHTIG: Der Log Group Name muss exakt "/aws/lambda/<function_name>" sein –
# Lambda schreibt Logs automatisch in diese Log Group.
#
# resource "aws_cloudwatch_log_group" "lambda" { ... }
# resource "aws_lambda_function" "api" { ... }

# --- API Gateway v2 (HTTP API) ---

# TODO 2: API Gateway implementieren
# Vier Ressourcen bauen zusammen die HTTP API:
#
# 1. aws_apigatewayv2_api       – die API selbst (protocol_type = "HTTP")
# 2. aws_apigatewayv2_integration – verbindet API mit der Lambda (AWS_PROXY)
# 3. aws_apigatewayv2_route     – je eine Route für POST /claims, GET /claims, GET /claims/{id}
# 4. aws_lambda_permission      – erlaubt API Gateway, die Lambda aufzurufen
#
# resource "aws_apigatewayv2_api" "claims" { ... }
# resource "aws_apigatewayv2_integration" "lambda" { ... }
# resource "aws_apigatewayv2_route" "create_claim" { ... }
# resource "aws_apigatewayv2_route" "get_claim" { ... }
# resource "aws_apigatewayv2_route" "list_claims" { ... }
# resource "aws_lambda_permission" "apigw" { ... }

# Vorgegeben: Stage-Konfiguration (Boilerplate)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.claims.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 100
  }

  tags = var.tags
}
