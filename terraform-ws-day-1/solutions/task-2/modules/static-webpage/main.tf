terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.frankfurt]
    }
  }
}

resource "aws_s3_bucket" "jasper-workshop-static-page" {
  bucket   = "workshop-${var.name}"
  provider = aws.frankfurt
}

resource "aws_s3_object" "jasper-workshop-static-page-index" {
  bucket       = aws_s3_bucket.jasper-workshop-static-page.id
  provider     = aws.frankfurt
  key          = "index.html"
  source       = var.filepath
  content_type = "text/html"
  etag         = filemd5(var.filepath)
}

resource "aws_s3_bucket_public_access_block" "jasper-workshop-static-page-public-access-block" {
  bucket   = aws_s3_bucket.jasper-workshop-static-page.id
  provider = aws.frankfurt

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "jasper-workshop-static-page-policy" {
  bucket     = aws_s3_bucket.jasper-workshop-static-page.id
  provider   = aws.frankfurt
  policy     = data.aws_iam_policy_document.allow_access_to_bucket.json
  depends_on = [aws_s3_bucket_public_access_block.jasper-workshop-static-page-public-access-block]
}

data "aws_iam_policy_document" "allow_access_to_bucket" {
  statement {
    # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document#principals-and-not_principals
    principals {
      identifiers = ["*"]
      type        = "*"
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.jasper-workshop-static-page.arn}/*"
    ]
  }
}


resource "aws_s3_bucket_website_configuration" "jasper-workshop-static-page-website-configuration" {
  bucket   = aws_s3_bucket.jasper-workshop-static-page.id
  provider = aws.frankfurt
  index_document {
    suffix = "index.html"
  }
}

output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.jasper-workshop-static-page-website-configuration.website_endpoint}"
}
