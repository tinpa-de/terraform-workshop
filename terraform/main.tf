terraform {
#  backend "s3" {
#    bucket = "terraform-state-nl-devk-workshop"
#    key    = "infrastructure-juli" # Change NAME to your name to avoid conflicts with other workshop participants
#    region = "eu-west-1"
#    dynamodb_table = "terraform-state-lock-juli"
#  }
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

