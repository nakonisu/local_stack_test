output "bucket_name" {
  description = "S3 bucket name for reports"
  value       = aws_s3_bucket.reports.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.reports.arn
}
