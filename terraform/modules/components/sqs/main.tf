# SQS キュー
resource "aws_sqs_queue" "task_processor" {
  name                       = "${var.project_name}-task-processor-${var.environment}"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 10
  visibility_timeout_seconds = 360 # Lambda関数のタイムアウト(300秒) + バッファ(60秒)

  # デッドレターキュー設定
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.task_processor_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${var.project_name}-task-processor"
    Environment = var.environment
  }
}

# デッドレターキュー
resource "aws_sqs_queue" "task_processor_dlq" {
  name = "${var.project_name}-task-processor-dlq-${var.environment}"

  tags = {
    Name        = "${var.project_name}-task-processor-dlq"
    Environment = var.environment
  }
}
