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
            Principal = "*"
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

output "website_url" {
  value = "http://${aws_s3_bucket_website_configuration.bucket_website_configuration.website_endpoint}"
}