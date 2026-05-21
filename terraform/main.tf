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

  name     = "NAME-workshop-static-page"
  filepath = "../resources/static-page/index.html"
}

module "static_page_2" {
  source = "./modules/static-webpage"

  providers = {
    aws.frankfurt = aws.frankfurt
  }

  name     = "NAME-workshop-static-page-2"
  filepath = "../resources/static-page-2/index.html"
}

module "static_page_3" {
  source = "./modules/static-webpage"

  providers = {
    aws.frankfurt = aws.frankfurt
  }

  name     = "NAME-workshop-static-page-3"
  filepath = "../resources/static-page-3/index.html"
}

output "website_url_1" {
  value = module.static_page_1.website_url
}

output "website_url_2" {
  value = module.static_page_2.website_url
}

output "website_url_3" {
  value = module.static_page_3.website_url
}