terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.frankfurt]
    }
  }
}

resource "aws_s3_bucket" "my_first_s3_bucket" {
    bucket = var.name
}

resource "aws_s3_object" "my_first_s3_object" {
    bucket = aws_s3_bucket.my_first_s3_bucket.bucket
    key = "index.html"
    source = var.filepath
    content_type = "text/html"
    etag = filemd5(var.filepath)
}

resource "aws_s3_bucket_policy" "allow_public_website_access" {
    bucket = aws_s3_bucket.my_first_s3_bucket.id
    # depends_on = [aws_s3_bucket_public_access_block.public_access_block]
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect    = "Allow"
            Principal = {
              Service = "cloudfront.amazonaws.com"
            }
            Condition = {
                StringEquals = {
                    "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
                }
                }
            Action    = "s3:GetObject"
            Resource  = "arn:aws:s3:::${var.name}/*"
        }]
    })
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default-oac-${var.name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.my_first_s3_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = "s3_origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3_origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "website_url" {
  value = "https://${aws_cloudfront_distribution.s3_distribution.domain_name}"
}