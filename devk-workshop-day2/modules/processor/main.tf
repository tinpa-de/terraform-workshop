data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/processor.zip"
}

# IAM-Rolle wurde vorab vom Admin angelegt (WorkshopParticipant hat kein iam:CreateRole/GetRole).
# ARN wird direkt konstruiert, um iam:GetRole zu vermeiden.
data "aws_caller_identity" "current" {}

locals {
  role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-${var.environment}-processor-role"
}

# CloudWatch Log Group explizit verwalten (statt implizit von Lambda) -> Retention setzbar
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}-${var.environment}-claims-processor"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_lambda_function" "processor" {
  function_name    = "${var.project}-${var.environment}-claims-processor"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  role             = local.role_arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  layers = var.layers

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_PORT     = "5432"
      DB_NAME     = var.db_name
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
      LOG_LEVEL   = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
  tags       = var.tags
}

resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.bucket_arn
}

resource "aws_s3_bucket_notification" "trigger" {
  bucket = var.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3]
}
