resource "aws_s3_bucket" "example-bucket" {
  bucket = "my-tf-test-bucket" # Exchange this with a custom name

  provider = aws.frankfurt
}

resource "aws_s3_object" "example-object" {
  bucket = aws_s3_bucket.example-bucket.id
  key    = "index"
  source = "../resources/static-page/index.html"

  etag = filemd5("../resources/static-page/index.html")
}

resource "aws_s3_bucket_public_access_block" "example-access" {
  bucket = aws_s3_bucket.example-bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.example-bucket.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::example-bucket/*"
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.access_block]
  
  provider = aws.frankfurt
}

