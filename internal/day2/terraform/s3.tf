# =============================================================================
# Part 1: Storage - the bucket that holds the feedback
# =============================================================================
#
# Goal:
#   Recreate the bucket you clicked together on Day 1, this time in code:
#   private, versioned, encrypted.
#
# Requirements:
#   1. An S3 bucket named local.bucket_name, tagged with local.tags.
#   2. Versioning enabled - an overwritten object keeps its old version.
#   3. Server-side encryption with AES256 (SSE-S3).
#   4. Block Public Access fully switched on (all four flags true).
#
# Note that 2-4 are separate resources, not arguments on the bucket. AWS
# models them as separate APIs, and Terraform follows the API.
#
# Terraform documentation:
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration
#   https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block
#
# Tip:
#   Write one resource, run `terraform plan`, read the output, then write the
#   next one. Do not write all four and hope.

# TODO 1.1 - the bucket itself
#
# resource "aws_s3_bucket" "feedback" {
#   ...
# }

# TODO 1.2 - versioning
#
# resource "aws_s3_bucket_versioning" "feedback" {
#   ...
# }

# TODO 1.3 - server-side encryption
#
# resource "aws_s3_bucket_server_side_encryption_configuration" "feedback" {
#   ...
# }

# TODO 1.4 - block public access
#
# resource "aws_s3_bucket_public_access_block" "feedback" {
#   ...
# }
