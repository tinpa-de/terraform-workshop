# =============================================================================
# Given - provider configuration and naming. You do not need to change this.
# =============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region = var.region
}

locals {
  # Everything you build today is prefixed with this plus your own name
  # suffix, so that the whole group can work in one AWS account without
  # colliding. The "tf" marks these as the Terraform-built resources - your
  # Day 1 resources carry "manual" instead and are left untouched.
  name_prefix = "${var.project}-${var.environment}-feedback"

  bucket_name   = "${local.name_prefix}-tf-${var.name_suffix}"
  function_name = "${local.name_prefix}-api-tf-${var.name_suffix}"
  api_name      = "${local.name_prefix}-tf-${var.name_suffix}"

  # The Lambda execution role was created once by the facilitator and is
  # shared by everyone, so it carries no name suffix.
  iam_role_name = "${local.name_prefix}-api-role"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Workshop    = "NL-2026"
  }
}
