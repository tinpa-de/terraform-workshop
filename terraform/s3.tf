resource "aws_s3_bucket" "my_first_s3_bucket" {
    bucket = "juli-walkthrough1-workshop-static-page"
}

resource "aws_s3_object" "my_first_s3_object" {
    bucket = aws_s3_bucket.my_first_s3_bucket.bucket
    key = "index.html"
    source = "../resources/static-page/index.html"
    content_type = "text/html"
    etag = filemd5("../resources/static-page/index.html")
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.my_first_s3_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_public_website_access" {
    bucket = aws_s3_bucket.my_first_s3_bucket.id
    depends_on = [aws_s3_bucket_public_access_block.public_access_block]
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect    = "Allow"
            Principal = "cloudfront.amazonaws.com"
            Action    = "s3:GetObject"
            Resource  = "arn:aws:s3:::juli-walkthrough1-workshop-static-page/*"
        }]
    })
}

resource "aws_s3_bucket_website_configuration" "bucket_website_configuration" {
  bucket = aws_s3_bucket.my_first_s3_bucket.id

  index_document {
    suffix = "index.html"
  }

}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default-oac"
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
  value = "http://${aws_s3_bucket_website_configuration.bucket_website_configuration.website_endpoint}"
}