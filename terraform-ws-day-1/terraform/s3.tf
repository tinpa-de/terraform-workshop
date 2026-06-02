resource "aws_s3_bucket" "jasper-workshop-static-page" {
  bucket = "jasper-nl-20260602"
  provider = aws.frankfurt
}
