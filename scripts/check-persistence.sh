#!/bin/bash

echo "🔍 データ永続化状況確認スクリプト"
echo "================================="

echo ""
echo "1️⃣ LocalStackコンテナ状況:"
docker ps | grep localstack

echo ""
echo "2️⃣ 永続化設定確認:"
echo "PERSISTENCE環境変数:"
docker exec localstack-main env | grep PERSISTENCE || echo "PERSISTENCE設定が見つかりません"

echo ""
echo "3️⃣ 永続化ディレクトリ:"
echo "localstack-data/:"
ls -la localstack-data/ | head -10

echo ""
echo "4️⃣ 現在のDynamoDBタスク数:"
TASK_COUNT=$(aws --endpoint-url=http://localhost:4566 dynamodb scan --table-name task-manager-tasks-local --region us-east-1 --query 'Count' --output text 2>/dev/null)
echo "DynamoDBに保存されているタスク数: $TASK_COUNT"

echo ""
echo "5️⃣ 各ユーザーのタスク数:"
API_URL=$(cd terraform/environments/local && terraform output -raw api_gateway_url 2>/dev/null && cd ../../..)

for USER in "user-001" "user-002" "user-003"; do
    COUNT=$(curl -s "$API_URL/tasks?user_id=$USER" | jq '. | length' 2>/dev/null || echo "0")
    echo "$USER: $COUNT タスク"
done

echo ""
echo "6️⃣ タスクステータス別の数:"
COMPLETED_COUNT=$(curl -s "$API_URL/tasks?user_id=user-001" | jq '[.[] | select(.status == "completed")] | length' 2>/dev/null || echo "0")
IN_PROGRESS_COUNT=$(curl -s "$API_URL/tasks?user_id=user-001" | jq '[.[] | select(.status == "in_progress")] | length' 2>/dev/null || echo "0")
PENDING_COUNT=$(curl -s "$API_URL/tasks?user_id=user-001" | jq '[.[] | select(.status == "pending")] | length' 2>/dev/null || echo "0")

echo "完了: $COMPLETED_COUNT"
echo "進行中: $IN_PROGRESS_COUNT"
echo "待機中: $PENDING_COUNT"

echo ""
echo "✅ データ確認完了！"
echo ""
echo "📝 注意事項:"
echo "- LocalStack Community版では一部の永続化機能に制限があります"
echo "- 本格的な永続化にはLocalStack Pro版が推奨されます"
echo "- 開発環境では現在の設定で充分機能します"
