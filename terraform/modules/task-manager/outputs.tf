# API Gateway outputs
output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_gateway_url
}

# DynamoDB outputs
output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

# S3 outputs
output "s3_bucket_name" {
  description = "S3 bucket name for reports"
  value       = module.s3.bucket_name
}

# SQS outputs
output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = module.sqs.queue_url
}

# Lambda outputs
output "lambda_api_function_name" {
  description = "API Lambda function name"
  value       = module.lambda.api_lambda_function_name
}

output "lambda_worker_function_name" {
  description = "Worker Lambda function name"
  value       = module.lambda.worker_lambda_function_name
}
