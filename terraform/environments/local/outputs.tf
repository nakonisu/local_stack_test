# ローカル環境の出力値
output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = module.task_manager.api_gateway_url
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.task_manager.dynamodb_table_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for reports"
  value       = module.task_manager.s3_bucket_name
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = module.task_manager.sqs_queue_url
}
