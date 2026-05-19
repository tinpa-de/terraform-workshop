# Musterlösung: envs/dev/main.tf (vollständig ausgefüllt)
# Diese Datei zeigt, wie die Module korrekt verdrahtet werden.

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
    random  = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" {
  region = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Workshop    = "DEVK-2026"
  }

  psycopg2_layer_arn = "arn:aws:lambda:${var.region}:770693421928:layer:Klayers-p312-psycopg2-binary:1"
}

module "storage" {
  source      = "../../modules/storage"
  project     = var.project
  environment = var.environment
  suffix      = random_id.suffix.hex
  tags        = local.tags
}

module "database" {
  source      = "../../modules/database"
  project     = var.project
  environment = var.environment
  vpc_id      = data.aws_vpc.default.id
  subnet_ids  = data.aws_subnets.default.ids
  allowed_security_group_ids = [
    module.processor.security_group_id,
    module.api.security_group_id,
  ]
  db_name     = "claims"
  db_username = var.db_username
  db_password = var.db_password
  tags        = local.tags
}

module "processor" {
  source      = "../../modules/processor"
  project     = var.project
  environment = var.environment
  vpc_id      = data.aws_vpc.default.id
  subnet_ids  = data.aws_subnets.default.ids
  source_dir  = "${path.module}/../../lambda-src/processor"
  bucket_id   = module.storage.bucket_id
  bucket_arn  = module.storage.bucket_arn
  db_host     = module.database.address
  db_name     = module.database.db_name
  db_username = var.db_username
  db_password = var.db_password
  layers      = [local.psycopg2_layer_arn]
  tags        = local.tags
}

module "api" {
  source      = "../../modules/api"
  project     = var.project
  environment = var.environment
  vpc_id      = data.aws_vpc.default.id
  subnet_ids  = data.aws_subnets.default.ids
  source_dir  = "${path.module}/../../lambda-src/api"
  bucket_name = module.storage.bucket_name
  bucket_arn  = module.storage.bucket_arn
  db_host     = module.database.address
  db_name     = module.database.db_name
  db_username = var.db_username
  db_password = var.db_password
  layers      = [local.psycopg2_layer_arn]
  tags        = local.tags
}
