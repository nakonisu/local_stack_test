# IAMロール - Lambda実行用
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Lambda基本実行ポリシー
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution_role.name
}

# DynamoDB・S3・SQSアクセスポリシー
resource "aws_iam_role_policy" "lambda_service_policy" {
  name = "${var.project_name}-lambda-service-policy-${var.environment}"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.s3_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          var.sqs_queue_arn,
          var.sqs_dlq_arn
        ]
      }
    ]
  })
}

# Lambda関数用のZIPファイル作成
data "archive_file" "api_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../../../lambda/api_handler.py"
  output_path = "${path.module}/api_handler.zip"
}

data "archive_file" "worker_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../../../lambda/worker.py"
  output_path = "${path.module}/worker.zip"
}

# API Lambda関数
resource "aws_lambda_function" "api_handler" {
  filename         = data.archive_file.api_lambda_zip.output_path
  function_name    = "${var.project_name}-api-handler-${var.environment}"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "api_handler.lambda_handler"
  source_code_hash = data.archive_file.api_lambda_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 30

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      SQS_QUEUE_URL  = var.sqs_queue_url
    }
  }

  tags = {
    Name        = "${var.project_name}-api-handler"
    Environment = var.environment
  }
}

# Worker Lambda関数
resource "aws_lambda_function" "worker" {
  filename         = data.archive_file.worker_lambda_zip.output_path
  function_name    = "${var.project_name}-worker-${var.environment}"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "worker.lambda_handler"
  source_code_hash = data.archive_file.worker_lambda_zip.output_base64sha256
  runtime          = "python3.9"
  timeout          = 300

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      S3_BUCKET      = var.s3_bucket_name
    }
  }

  tags = {
    Name        = "${var.project_name}-worker"
    Environment = var.environment
  }
}

# SQSトリガー設定
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_queue_arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 1
}
