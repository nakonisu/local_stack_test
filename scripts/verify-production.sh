#!/bin/bash

echo "🔍 本番環境の動作確認を開始します..."

# AWSクレデンシャルチェック
echo "🔐 AWS認証情報を確認中..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS認証情報が設定されていません。"
    exit 1
fi

# Terraformアウトプット取得
echo "📊 Terraformアウトプットを取得中..."
cd terraform/environments/prod

# 各リソースのURLや名前を取得
API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null)
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)
SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url 2>/dev/null)

cd ../../..

if [ -z "$API_GATEWAY_URL" ]; then
    echo "❌ API Gateway URLが取得できませんでした。"
    exit 1
fi

echo "✅ リソース情報を取得しました:"
echo "  API Gateway: $API_GATEWAY_URL"
echo "  DynamoDB: $DYNAMODB_TABLE"
echo "  S3 Bucket: $S3_BUCKET"
echo "  SQS Queue: $SQS_QUEUE_URL"
echo ""

# 1. AWSリソースの状態確認
echo "🔍 1. AWSリソースの状態確認"
echo "----------------------------------------"

# DynamoDB確認
echo "📚 DynamoDB テーブル状態:"
aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region ap-northeast-1 \
    --query 'Table.{Name:TableName,Status:TableStatus,Items:ItemCount}' --output table

# Lambda関数確認
echo "⚡ Lambda 関数状態:"
aws lambda list-functions --region ap-northeast-1 \
    --query 'Functions[?contains(FunctionName, `task-manager`) && contains(FunctionName, `production`)].{Name:FunctionName,Runtime:Runtime,LastModified:LastModified}' \
    --output table

# S3バケット確認
echo "🪣 S3 バケット状態:"
if aws s3 ls "s3://$S3_BUCKET" --region ap-northeast-1 > /dev/null 2>&1; then
    echo "✅ S3バケット $S3_BUCKET は存在します"
else
    echo "❌ S3バケット $S3_BUCKET にアクセスできません"
fi

# SQS確認
echo "📬 SQS キュー状態:"
aws sqs get-queue-attributes --queue-url "$SQS_QUEUE_URL" --attribute-names ApproximateNumberOfMessages \
    --region ap-northeast-1 --query 'Attributes.ApproximateNumberOfMessages' --output text | \
    xargs -I {} echo "待機中のメッセージ数: {}"

echo ""

# 2. API機能テスト
echo "🧪 2. API機能テスト"
echo "----------------------------------------"

USER_ID="production-test-user-$(date +%s)"

# タスク一覧取得（空のはず）
echo "📋 タスク一覧取得テスト:"
TASK_LIST_RESPONSE=$(curl -s -X GET "$API_GATEWAY_URL/tasks?user_id=$USER_ID")
echo "レスポンス: $TASK_LIST_RESPONSE"

if echo "$TASK_LIST_RESPONSE" | jq empty > /dev/null 2>&1; then
    echo "✅ 正常なJSONレスポンスを受信"
else
    echo "❌ 無効なJSONレスポンス"
fi

# タスク作成
echo ""
echo "📝 タスク作成テスト:"
TASK_CREATE_RESPONSE=$(curl -s -X POST "$API_GATEWAY_URL/tasks" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"本番動作確認タスク\", \"description\": \"自動テストで作成されたタスク\", \"user_id\": \"$USER_ID\"}")

echo "レスポンス: $TASK_CREATE_RESPONSE"

# タスクIDを抽出
TASK_ID=$(echo "$TASK_CREATE_RESPONSE" | jq -r '.task_id // empty')

if [ -n "$TASK_ID" ]; then
    echo "✅ タスクが作成されました: $TASK_ID"
    
    # タスク詳細取得
    echo ""
    echo "🔍 タスク詳細取得テスト:"
    TASK_DETAIL_RESPONSE=$(curl -s -X GET "$API_GATEWAY_URL/tasks/$TASK_ID")
    echo "レスポンス: $TASK_DETAIL_RESPONSE"
    
    # タスク一覧で作成されたタスクを確認
    echo ""
    echo "📋 更新されたタスク一覧確認:"
    UPDATED_TASK_LIST=$(curl -s -X GET "$API_GATEWAY_URL/tasks?user_id=$USER_ID")
    echo "レスポンス: $UPDATED_TASK_LIST"
    
    # タスク更新
    echo ""
    echo "✏️ タスク更新テスト:"
    TASK_UPDATE_RESPONSE=$(curl -s -X PUT "$API_GATEWAY_URL/tasks/$TASK_ID" \
      -H "Content-Type: application/json" \
      -d '{"status": "completed", "description": "更新されたタスク"}')
    echo "レスポンス: $TASK_UPDATE_RESPONSE"
    
else
    echo "❌ タスクの作成に失敗しました"
fi

echo ""

# 3. データベース確認
echo "🗄️ 3. データベース確認"
echo "----------------------------------------"
echo "DynamoDB内のタスク数:"
ITEM_COUNT=$(aws dynamodb scan --table-name "$DYNAMODB_TABLE" --region ap-northeast-1 \
    --select COUNT --query 'Count' --output text)
echo "総タスク数: $ITEM_COUNT"

echo ""

# 4. ログ確認
echo "📋 4. Lambda ログ確認 (直近のエラー)"
echo "----------------------------------------"
for FUNCTION_NAME in "task-manager-api-handler-production" "task-manager-worker-production"; do
    echo "🔍 $FUNCTION_NAME のエラーログ:"
    aws logs filter-log-events \
        --log-group-name "/aws/lambda/$FUNCTION_NAME" \
        --region ap-northeast-1 \
        --start-time $(($(date +%s) - 300)) \
        --filter-pattern "ERROR" \
        --query 'events[*].message' \
        --output text 2>/dev/null | head -5 || echo "エラーログはありません（または権限不足）"
done

echo ""
echo "🎉 本番環境の動作確認が完了しました！"
echo ""
echo "📍 次の確認方法もあります:"
echo "  • AWS Console でリソースを視覚的に確認"
echo "  • CloudWatch でメトリクスとログを監視"
echo "  • API Gateway のテストコンソールでエンドポイントをテスト"
echo "  • X-Ray でリクエストトレースを確認（有効にしている場合）"
