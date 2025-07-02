#!/bin/bash

# 設定
API_URL=${1:-"http://localhost:4566/restapis"}
USER_ID="test-user-123"

echo "🧪 API テストを開始します..."
echo "API URL: $API_URL"
echo ""

# API Gateway URLを取得 (Terraformからの出力を利用)
if [ -f "terraform/environments/local/terraform.tfstate" ]; then
    cd terraform/environments/local
    API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
    cd ../../..
    if [ ! -z "$API_GATEWAY_URL" ]; then
        API_URL="$API_GATEWAY_URL"
        echo "✅ Terraformから取得したAPI URL: $API_URL"
    fi
fi

echo ""
echo "1️⃣ タスク作成テスト"
TASK_RESPONSE=$(curl -s -X POST "$API_URL/tasks" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"テストタスク\", \"description\": \"APIテスト用タスク\", \"user_id\": \"$USER_ID\"}")

echo "レスポンス: $TASK_RESPONSE"

# タスクIDを抽出
TASK_ID=$(echo $TASK_RESPONSE | jq -r '.task_id // empty')

if [ ! -z "$TASK_ID" ]; then
    echo "✅ タスクが作成されました: $TASK_ID"
    
    echo ""
    echo "2️⃣ タスク取得テスト"
    curl -s -X GET "$API_URL/tasks/$TASK_ID" | jq .
    
    echo ""
    echo "3️⃣ タスク一覧取得テスト"
    curl -s -X GET "$API_URL/tasks?user_id=$USER_ID" | jq .
    
    echo ""
    echo "4️⃣ タスク更新テスト"
    curl -s -X PUT "$API_URL/tasks/$TASK_ID" \
      -H "Content-Type: application/json" \
      -d '{"status": "completed", "description": "更新されたタスク"}' | jq .
    
    echo ""
    echo "5️⃣ レポート生成テスト"
    curl -s -X POST "$API_URL/tasks/report" \
      -H "Content-Type: application/json" \
      -d "{\"user_id\": \"$USER_ID\"}" | jq .
    
    echo ""
    echo "6️⃣ タスク削除テスト"
    curl -s -X DELETE "$API_URL/tasks/$TASK_ID"
    
    echo ""
    echo "✅ すべてのテストが完了しました！"
else
    echo "❌ タスクの作成に失敗しました"
fi
