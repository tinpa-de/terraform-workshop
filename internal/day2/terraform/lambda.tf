# =============================================================================
# Part 2: Compute - the Lambda function behind the API
# =============================================================================
#
# Goal:
#   Package ../lambda-src/api as a zip and deploy it as a Lambda function -
#   the same code you pasted into the console editor on Day 1.
#
# Requirements:
#   1. data "archive_file" that zips ../lambda-src/api into build/api.zip.
#   2. data "aws_iam_role" that looks up the shared execution role by name
#      (local.iam_role_name). The facilitator created it before the workshop -
#      it is the same role you picked from the dropdown on Day 1.
#   3. A CloudWatch log group with 14 days retention.
#   4. The Lambda function itself: runtime python3.13, handler
#      handler.lambda_handler, timeout 15, memory_size 256, and the
#      environment variable BUCKET_NAME pointing at your bucket.
#
# IMPORTANT: The log group name must be exactly "/aws/lambda/<function_name>".
# Lambda writes to that name whether or not the group exists. Declaring it
# yourself is what gives you control over retention - and what lets Terraform
# delete it again on destroy.
#
# Terraform documentation:
#   https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_role
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
#
# Tip:
#   A `data` block reads something that already exists. A `resource` block
#   owns its object's whole lifecycle. Getting this distinction wrong is how
#   people accidentally delete other teams' infrastructure.

# TODO 2.1 - zip the source directory
#
# data "archive_file" "api" {
#   ...
# }

# TODO 2.2 - look up the shared execution role
#
# data "aws_iam_role" "api" {
#   ...
# }

# TODO 2.3 - log group
#
# resource "aws_cloudwatch_log_group" "api" {
#   ...
# }

# TODO 2.4 - the function
#
# resource "aws_lambda_function" "api" {
#   ...
# }
