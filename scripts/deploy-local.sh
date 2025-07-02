#!/bin/bash

echo "🚀 LocalStack環境のセットアップを開始します..."

# LocalStack起動
echo "📦 LocalStackを起動中..."
docker-compose up -d

# LocalStackの起動待機
echo "⏳ LocalStackの準備を待機中..."
sleep 20

# LocalStackのヘルスチェック
echo "🔍 LocalStackのヘルスチェック..."
for i in {1..5}; do
  if curl -s http://localhost:4566/health | jq . > /dev/null 2>&1; then
    echo "✅ LocalStackが正常に起動しました"
    break
  else
    echo "⏳ LocalStackの起動を待機中... ($i/5)"
    sleep 10
  fi
done

# Terraformの初期化
echo "🏗️ Terraformを初期化中..."
cd terraform/environments/local
terraform init

# Terraformプラン
echo "📋 Terraformプランを確認中..."
terraform plan

# Terraformアプライ
echo "🏗️ インフラをデプロイ中..."
terraform apply -auto-approve

# 結果の表示
echo "✅ デプロイ完了！"
echo "📊 作成されたリソース:"
terraform output

echo ""
echo "🧪 テスト用コマンド:"
echo "API Gateway URL: $(terraform output -raw api_gateway_url)"
echo ""
echo "📝 タスク作成テスト:"
echo 'curl -X POST "$(terraform output -raw api_gateway_url)/tasks" \'
echo '  -H "Content-Type: application/json" \'
echo '  -d '"'"'{"title": "テストタスク", "description": "ローカル環境でのテスト", "user_id": "user-123"}'"'"''

cd ../..