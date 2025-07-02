# API Gateway
resource "aws_api_gateway_rest_api" "task_api" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "Task Management API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

# API Gateway Lambda統合用の権限
resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/*/*"
}

# /tasks リソース
resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "tasks"
}

# /tasks/{task_id} リソース
resource "aws_api_gateway_resource" "task_detail" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_resource.tasks.id
  path_part   = "{task_id}"
}

# /tasks/report リソース
resource "aws_api_gateway_resource" "report" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_resource.tasks.id
  path_part   = "report"
}

# メソッド定義用ローカル変数
locals {
  methods = [
    {
      resource_id   = aws_api_gateway_resource.tasks.id
      http_method   = "GET"
      authorization = "NONE"
    },
    {
      resource_id   = aws_api_gateway_resource.tasks.id
      http_method   = "POST"
      authorization = "NONE"
    },
    {
      resource_id   = aws_api_gateway_resource.task_detail.id
      http_method   = "GET"
      authorization = "NONE"
    },
    {
      resource_id   = aws_api_gateway_resource.task_detail.id
      http_method   = "PUT"
      authorization = "NONE"
    },
    {
      resource_id   = aws_api_gateway_resource.task_detail.id
      http_method   = "DELETE"
      authorization = "NONE"
    },
    {
      resource_id   = aws_api_gateway_resource.report.id
      http_method   = "POST"
      authorization = "NONE"
    }
  ]
}

# メソッド作成
resource "aws_api_gateway_method" "methods" {
  count         = length(local.methods)
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = local.methods[count.index].resource_id
  http_method   = local.methods[count.index].http_method
  authorization = local.methods[count.index].authorization
}

# Lambda統合
resource "aws_api_gateway_integration" "lambda_integration" {
  count       = length(local.methods)
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = local.methods[count.index].resource_id
  http_method = aws_api_gateway_method.methods[count.index].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# CORS用 OPTIONS メソッド
resource "aws_api_gateway_method" "options_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "options_task_detail" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_detail.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "options_report" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.report.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# CORS統合
resource "aws_api_gateway_integration" "options_integration_tasks" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.options_tasks.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "options_integration_task_detail" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.task_detail.id
  http_method = aws_api_gateway_method.options_task_detail.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "options_integration_report" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.report.id
  http_method = aws_api_gateway_method.options_report.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# CORS レスポンス
resource "aws_api_gateway_method_response" "options_response_tasks" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.options_tasks.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response_tasks" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = aws_api_gateway_method.options_tasks.http_method
  status_code = aws_api_gateway_method_response.options_response_tasks.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# API デプロイメント
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.options_integration_tasks,
    aws_api_gateway_integration.options_integration_task_detail,
    aws_api_gateway_integration.options_integration_report
  ]

  rest_api_id = aws_api_gateway_rest_api.task_api.id

  lifecycle {
    create_before_destroy = true
  }
}

# API ステージ
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  stage_name    = var.environment
}
