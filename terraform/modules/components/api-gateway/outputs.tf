output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = var.use_localstack ? "http://localhost:4566/restapis/${aws_api_gateway_rest_api.task_api.id}/${var.environment}/_user_request_" : "https://${aws_api_gateway_rest_api.task_api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_api_gateway_rest_api.task_api.id
}
