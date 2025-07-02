# 本番環境用のTerraform設定

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

  # 本番環境ではリモートバックエンドを推奨
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "task-manager/production/terraform.tfstate"
  #   region = "ap-northeast-1"
  # }
}

# 本番環境設定
locals {
  environment    = var.environment
  aws_region     = var.aws_region
  project_name   = var.project_name
  use_localstack = var.use_localstack
  aws_profile    = var.aws_profile
}

# AWS Provider設定 (本番)
provider "aws" {
  region  = local.aws_region
  profile = local.aws_profile
  # 本番では標準のAWSエンドポイントを使用
}

# Task Managerアプリケーションモジュールを呼び出し
module "task_manager" {
  source = "../../modules/task-manager"

  environment    = local.environment
  aws_region     = local.aws_region
  project_name   = local.project_name
  use_localstack = local.use_localstack
}
