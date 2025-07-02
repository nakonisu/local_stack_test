output "queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.task_processor.url
}

output "queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.task_processor.arn
}

output "dlq_arn" {
  description = "SQS dead letter queue ARN"
  value       = aws_sqs_queue.task_processor_dlq.arn
}
