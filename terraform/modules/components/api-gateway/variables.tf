variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (local, dev, prod)"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name to integrate with"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Lambda function invoke ARN"
  type        = string
}

variable "use_localstack" {
  description = "Whether to use LocalStack endpoints"
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
