output "api_lambda_function_name" {
  description = "API Lambda function name"
  value       = aws_lambda_function.api_handler.function_name
}

output "api_lambda_invoke_arn" {
  description = "API Lambda function invoke ARN"
  value       = aws_lambda_function.api_handler.invoke_arn
}

output "worker_lambda_function_name" {
  description = "Worker Lambda function name"
  value       = aws_lambda_function.worker.function_name
}
