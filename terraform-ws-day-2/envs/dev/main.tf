terraform {
  required_version = ">= 1.6"

  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }
}

provider "aws" {
  region = var.region
}

# Default VPC – wird für den Security-Group-Lookup im Database-Modul gebraucht
data "aws_vpc" "default" {
  default = true
}

locals {
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Workshop    = "DEVK-2026"
  }

}

# =============================================================================
# Part 1: Foundation – Storage & Database
# =============================================================================

# TODO A: Storage-Modul aufrufen
# Schaut euch modules/storage/variables.tf und modules/storage/outputs.tf an.
# Der Bucket-Name wird später von processor + api gebraucht.
#
module "storage" {
  source      = "../../modules/storage"
  project     = var.project
  environment = var.environment
  tags        = local.tags
}

# TODO B: Datenbank-Modul aufrufen
# Schaut euch modules/database/variables.tf und modules/database/outputs.tf an.
# Die DB-Adresse wird später von processor + api gebraucht.
#
module "database" {
  source      = "../../modules/database"
  project     = var.project
  environment = var.environment
  vpc_id      = data.aws_vpc.default.id
  db_name     = "claims"
  db_username = var.db_username
  db_password = var.db_password
  tags        = local.tags
}

# =============================================================================
# Part 2: Application – Lambda & API Gateway
# (vorgegeben – beobachten und verstehen)
# =============================================================================

# TODO C: Processor-Modul einbinden – erst nach TODO B (database) aktivieren
# module "processor" {
#   source      = "../../modules/processor"
#   project     = var.project
#   environment = var.environment
#   source_dir  = "${path.module}/../../lambda-src/processor"
#   bucket_id   = module.storage.bucket_id
#   bucket_arn  = module.storage.bucket_arn
#   db_host     = module.database.address
#   db_name     = module.database.db_name
#   db_username = var.db_username
#   db_password = var.db_password
#   tags        = local.tags
# }

# TODO D: API-Modul einbinden – erst nach TODO C (database) aktivieren
# module "api" {
#   source      = "../../modules/api"
#   project     = var.project
#   environment = var.environment
#   source_dir  = "${path.module}/../../lambda-src/api"
#   bucket_name = module.storage.bucket_name
#   bucket_arn  = module.storage.bucket_arn
#   db_host     = module.database.address
#   db_name     = module.database.db_name
#   db_username = var.db_username
#   db_password = var.db_password
#   tags        = local.tags
# }
