#!/bin/bash

echo "🚀 AWS本番環境のデプロイを開始します..."

# AWSクレデンシャルチェック
echo "🔐 AWS認証情報を確認中..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS認証情報が設定されていません。"
    echo "aws configure を実行して認証情報を設定してください。"
    exit 1
fi

echo "✅ AWS認証情報を確認しました"
aws sts get-caller-identity

# Terraformの初期化
echo "🏗️ Terraformを初期化中..."
cd terraform/environments/production
terraform init

# Terraformプラン
echo "📋 Terraformプランを確認中..."
terraform plan

# 確認プロンプト
echo ""
read -p "本番環境にデプロイしますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "デプロイをキャンセルしました。"
    exit 1
fi

# Terraformアプライ
echo "🏗️ 本番環境にデプロイ中..."
terraform apply -auto-approve

# 結果の表示
echo "✅ 本番デプロイ完了！"
echo "📊 作成されたリソース:"
terraform output

echo ""
echo "🧪 本番環境テスト用コマンド:"
echo "API Gateway URL: $(terraform output -raw api_gateway_url)"

cd ../../..
