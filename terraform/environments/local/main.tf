# ローカル環境用のTerraform設定

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# ローカル環境設定
locals {
  environment         = var.environment
  aws_region          = var.aws_region
  project_name        = var.project_name
  use_localstack      = var.use_localstack
  localstack_endpoint = var.localstack_endpoint
}

# LocalStack用Provider設定
provider "aws" {
  region = local.aws_region

  # LocalStack用エンドポイント
  endpoints {
    apigateway     = local.localstack_endpoint
    lambda         = local.localstack_endpoint
    dynamodb       = local.localstack_endpoint
    s3             = local.localstack_endpoint
    sqs            = local.localstack_endpoint
    sns            = local.localstack_endpoint
    iam            = local.localstack_endpoint
    cloudformation = local.localstack_endpoint
  }

  # LocalStack用認証情報
  access_key = "test"
  secret_key = "test"

  # LocalStack用設定
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

# Task Managerアプリケーションモジュールを呼び出し
module "task_manager" {
  source = "../../modules/task-manager"

  environment    = local.environment
  aws_region     = local.aws_region
  project_name   = local.project_name
  use_localstack = local.use_localstack
}
