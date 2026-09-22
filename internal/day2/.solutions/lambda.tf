# Solution: terraform/lambda.tf

data "archive_file" "api" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda-src/api"
  output_path = "${path.module}/build/api.zip"
}

data "aws_iam_role" "api" {
  name = local.iam_role_name
}

# The name must match what Lambda writes to, otherwise you end up with two
# log groups: this one, empty, and an auto-created one with all the logs.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_lambda_function" "api" {
  function_name = local.function_name
  role          = data.aws_iam_role.api.arn
  runtime       = "python3.13"
  handler       = "handler.lambda_handler"
  timeout       = 15
  memory_size   = 256

  filename = data.archive_file.api.output_path

  # Without this, Terraform has no way to notice that the code changed and
  # will happily report "No changes" after you edit handler.py.
  source_code_hash = data.archive_file.api.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.feedback.bucket
    }
  }

  # Create the log group first, so Lambda does not create it with infinite
  # retention on the first invocation.
  depends_on = [aws_cloudwatch_log_group.api]

  tags = local.tags
}
