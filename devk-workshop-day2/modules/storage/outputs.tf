output "bucket_id" {
  description = "ID des S3-Buckets (entspricht dem Bucket-Namen)"
  value       = aws_s3_bucket.claims.id
}

output "bucket_arn" {
  description = "ARN des S3-Buckets, wird für IAM-Policies benötigt"
  value       = aws_s3_bucket.claims.arn
}

output "bucket_name" {
  description = "Name des S3-Buckets"
  value       = aws_s3_bucket.claims.bucket
}
