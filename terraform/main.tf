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
  alias  = "frankfurt"
  region = var.region
}

