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

module "static_page_1" {
  source = "./modules/static-webpage"

  providers = {
    aws.frankfurt = aws.frankfurt
  }

  name     = "juli-walkthrough1-workshop-static-page"
  filepath = "../resources/static-page/index.html"
}

output "website_url_1" {
  value = module.static_page_1.website_url
}