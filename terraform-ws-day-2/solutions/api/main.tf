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
# Unterschiede: function_name endet auf "claims-api-VORNAME", timeout = 15, memory_size = 256.
# Zusätzliche Env-Variable: BUCKET_NAME = var.bucket_name
# IAM-Rolle: data.aws_iam_role.api.arn
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

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}-${var.environment}-claims-api-VORNAME"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_lambda_function" "api" {
  function_name    = "${var.project}-${var.environment}-claims-api-VORNAME"
  filename         = data.archive_file.api_lambda.output_path
  source_code_hash = data.archive_file.api_lambda.output_base64sha256
  role             = data.aws_iam_role.api.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 15
  memory_size      = 256

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_PORT     = "5432"
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
      BUCKET_NAME = var.bucket_name
      LOG_LEVEL   = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
  tags       = var.tags
}

# --- API Gateway v2 (HTTP API) ---

resource "aws_apigatewayv2_api" "claims" {
  name          = "${var.project}-${var.environment}-claims-api-VORNAME"
  protocol_type = "HTTP"
  description   = "DEVK Claims Intake API"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }

  tags = var.tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.claims.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "create_claim" {
  api_id    = aws_apigatewayv2_api.claims.id
  route_key = "POST /claims"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "get_claim" {
  api_id    = aws_apigatewayv2_api.claims.id
  route_key = "GET /claims/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "list_claims" {
  api_id    = aws_apigatewayv2_api.claims.id
  route_key = "GET /claims"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.claims.execution_arn}/*/*"
}