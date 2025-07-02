# DynamoDB Module
module "dynamodb" {
  source = "../components/dynamodb"

  project_name = var.project_name
  environment  = var.environment
}

# S3 Module
module "s3" {
  source = "../components/s3"

  project_name = var.project_name
  environment  = var.environment
}

# SQS Module
module "sqs" {
  source = "../components/sqs"

  project_name = var.project_name
  environment  = var.environment
}

# Lambda Module
module "lambda" {
  source = "../components/lambda"

  project_name        = var.project_name
  environment         = var.environment
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  s3_bucket_name      = module.s3.bucket_name
  s3_bucket_arn       = module.s3.bucket_arn
  sqs_queue_url       = module.sqs.queue_url
  sqs_queue_arn       = module.sqs.queue_arn
  sqs_dlq_arn         = module.sqs.dlq_arn
}

# API Gateway Module
module "api_gateway" {
  source = "../components/api-gateway"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  use_localstack       = var.use_localstack
  lambda_function_name = module.lambda.api_lambda_function_name
  lambda_invoke_arn    = module.lambda.api_lambda_invoke_arn
}
