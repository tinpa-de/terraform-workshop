terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.8.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "backend_bucket" {
  bucket = "terraform-state-nl-devk"
}

resource "aws_dynamodb_table" "backend_lock_table" {
  name = var.dynamodb_table_name
  hash_key = "LockID"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }
}