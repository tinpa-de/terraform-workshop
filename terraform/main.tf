terraform {
  backend "s3" {
    bucket = "terraform-state-nl-devk"
    key    = "infrastructure-NAME" # Change NAME to your name to avoid conflicts with other workshop participants
  }
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

