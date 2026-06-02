resource "aws_s3_bucket" "jasper-workshop-static-page" {
  bucket = "jasper-nl-20260602"
  provider = aws.frankfurt
}

resource "aws_s3_object" "jasper-workshop-static-page-index" {
  bucket = aws_s3_bucket.jasper-workshop-static-page.id
  key = "index.html"
  source = "../resources/static-page/index.html"
  content_type = "text/html"
  etag = filemd5("../resources/static-page/index.html")
}
