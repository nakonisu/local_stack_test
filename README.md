# 概要

AWS 上でのシステム開発において、ローカルでのテスト環境を整える例をまとめたレポジトリです。
レポジトリの内容は README_REPOSITORY.md にまとめています。

- Docker により、AWS のローカル環境を構築する環境を整える
- terraform のプロバイダーに local の URL を指定する
- 他の部分はそのままで apply すると、ローカルで構築される

# LocalStack + Terraform ローカル AWS 開発環境まとめ

## 概要

LocalStack と Terraform を使うことで、AWS 本番環境とほぼ同じ構成をローカルで再現し、開発・テストができます。クラウド利用料金を抑えつつ、Infrastructure as Code の実践学習にも最適です。

---

## 1. 環境構成の流れ

1. **Docker Compose** で LocalStack コンテナを起動（AWS サービスのエミュレーション環境）
2. **Terraform** で LocalStack 内に AWS リソースを作成・設定

---

## 2. docker-compose.yml（AWS のリソースを立てる箱の作成）

```yaml
services:
  localstack:
    container_name: localstack-main
    image: localstack/localstack:3.0
    ports:
      - "4566:4566" # LocalStack Gateway
      - "4510-4559:4510-4559" # external services port range
    environment:
      - DEBUG=1
      - DOCKER_HOST=unix:///var/run/docker.sock
      - LAMBDA_EXECUTOR=docker-reuse
      - SERVICES=lambda,apigateway,dynamodb,s3,sqs,sns,iam,cloudformation
      - PERSISTENCE=0
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
    networks:
      - localstack-net

networks:
  localstack-net:
    driver: bridge
```

- **ポート 4566**: LocalStack の統一エンドポイント
- **SERVICES**: 使用する AWS サービスを明示的に指定
- **PERSISTENCE=0**: データ永続化なし（開発用途）

---

## 3. Terraform 設定のポイント

- provider "aws" の endpoint を `http://localhost:4566` に設定
- 認証情報は `test/test` 固定値
- `s3_use_path_style = true` など LocalStack 用の特殊設定

例:

```hcl
provider "aws" {
  region = "us-east-1"
  endpoints {
    apigateway     = "<http://localhost:4566>"
    lambda         = "<http://localhost:4566>"
    dynamodb       = "<http://localhost:4566>"
    s3             = "<http://localhost:4566>"
    sqs            = "<http://localhost:4566>"
    sns            = "<http://localhost:4566>"
    iam            = "<http://localhost:4566>"
    cloudformation = "<http://localhost:4566>"
  }
  access_key = "test"
  secret_key = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}
```

---

## 4. 開発フロー（ローカル）

```bash
# 1. LocalStack起動（箱を用意）
docker-compose up -d

# 2. AWSリソース作成（Dockerコンテナの中身を構築）
cd terraform/environments/local
terraform init
terraform apply
```

---

## 5. ローカルと本番の切り替え

Terraform では**環境別のディレクトリ**と**terraform.tfvars**で切り替えを行います。

### ローカル環境での実行

```bash
cd terraform/environments/local
terraform init
terraform apply

```

**local/terraform.tfvars**:

```hcl
environment         = "local"
aws_region          = "us-east-1"
project_name        = "task-manager"
localstack_endpoint = "<http://localhost:4566>" # LocalStackエンドポイント
```

**local/main.tf** の provider 設定:

```hcl
provider "aws" {
  region = local.aws_region
  # LocalStack用エンドポイント
  endpoints {
    apigateway     = local.localstack_endpoint
    lambda         = local.localstack_endpoint
    # ... 他のサービス
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

```

### **本番環境**での実行

```bash
cd terraform/environments/prod
terraform init
terraform apply
```

**prod/terraform.tfvars**:

```hcl
environment    = "production"
aws_region     = "ap-northeast-1"
project_name   = "task-manager"
aws_profile    = "personal_nishio"       # AWS認証プロファイル
```

**prod/main.tf** の provider 設定:

```hcl
provider "aws" {
  region  = local.aws_region
  profile = local.aws_profile
  # 標準のAWSエンドポイントを使用（endpointsブロックなし）
}
```
