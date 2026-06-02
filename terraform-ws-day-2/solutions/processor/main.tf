data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/processor.zip"
}

# IAM-Rolle wurde vorab vom Admin angelegt – hier wird sie per Name nachgeschlagen.
data "aws_iam_role" "processor" {
  name = "${var.project}-${var.environment}-processor-role"
}

# CloudWatch Log Group explizit verwalten (statt implizit von Lambda) -> Retention setzbar
# WICHTIG: Der Name muss exakt "/aws/lambda/<function_name>" sein –
# Lambda schreibt Logs automatisch in diese Log Group.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}-${var.environment}-claims-processor-VORNAME"
  retention_in_days = 7
  tags              = var.tags
}

resource "aws_lambda_function" "processor" {
  function_name    = "${var.project}-${var.environment}-claims-processor-VORNAME"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  role             = data.aws_iam_role.processor.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

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

# TODO: S3-Trigger implementieren – verbindet den Bucket mit der Lambda.
# Zwei Ressourcen werden gebraucht, die zusammenarbeiten:
#
# Ressource 1: aws_lambda_permission
#   Erlaubt S3, diese Lambda aufzurufen (ohne diese Permission blockiert AWS den Aufruf).
#
# Ressource 2: aws_s3_bucket_notification
#   Konfiguriert den Bucket so, dass er bei bestimmten Events die Lambda triggert.
#
# resource "aws_lambda_permission" "s3" {
#   ...
# }
#
# resource "aws_s3_bucket_notification" "trigger" {
#   ...
# }

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
