terraform {
  required_version = ">= 1.6"

  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
    random  = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" {
  region = var.region
}

# Eindeutiger Suffix für globalen S3-Namespace
resource "random_id" "suffix" {
  byte_length = 4
}

# Default VPC + Subnets – RDS braucht eine Subnet Group (mindestens 2 AZs)
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

  # Öffentlicher Lambda Layer für psycopg2 (Postgres-Client für Python).
  # Quelle: https://github.com/keithrozario/Klayers (Account 770693421928)
  # Aktuelle ARNs für eu-central-1: https://api.klayers.cloud/api/v2/p3.12/layers/latest/eu-central-1/html
  psycopg2_layer_arn = "arn:aws:lambda:${var.region}:770693421928:layer:Klayers-p312-psycopg2-binary:1"
}

# =============================================================================
# Part 1: Foundation – Storage & Database
# =============================================================================

# TODO A: Storage-Modul aufrufen
# Schaut euch modules/storage/outputs.tf an – welche Outputs gibt das Modul?
# Der Bucket-Name wird später von processor + api gebraucht.
#
module "storage" {
  source      = "../../modules/storage"
  project     = var.project
  environment = var.environment
  suffix      = random_id.suffix.hex
  tags        = local.tags
}

# TODO B: Database-Modul vervollständigen
# Schaut euch modules/database/variables.tf an.
# Welche Werte müssen für db_name, db_username und db_password übergeben werden?
#
module "database" {
  source      = "../../modules/database"
  project     = var.project
  environment = var.environment
  vpc_id      = data.aws_vpc.default.id
  subnet_ids  = data.aws_subnets.default.ids
  db_name     = "claims"
  db_username = var.db_username
  db_password = var.db_password
  tags        = local.tags
}

# =============================================================================
# Part 2: Application – Lambda & API Gateway
# (vorgegeben – beobachten und verstehen)
# =============================================================================

module "processor" {
  source      = "../../modules/processor"
  project     = var.project
  environment = var.environment
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
