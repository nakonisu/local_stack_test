import json
import boto3
import uuid
import os
from datetime import datetime
from decimal import Decimal

# 環境変数から設定を取得
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE")
SQS_QUEUE_URL = os.environ.get("SQS_QUEUE_URL")

# AWSクライアント初期化
dynamodb = boto3.resource("dynamodb")
sqs = boto3.client("sqs")


def lambda_handler(event, context):
    """
    API Gateway経由でタスクのCRUD操作を処理
    """
    try:
        http_method = event["httpMethod"]
        path = event["path"]

        if http_method == "POST" and path == "/tasks":
            return create_task(event)
        elif http_method == "GET" and path == "/tasks":
            return get_tasks(event)
        elif http_method == "GET" and "/tasks/" in path:
            return get_task(event)
        elif http_method == "PUT" and "/tasks/" in path:
            return update_task(event)
        elif http_method == "DELETE" and "/tasks/" in path:
            return delete_task(event)
        elif http_method == "POST" and path == "/tasks/report":
            return generate_report(event)
        else:
            return {
                "statusCode": 404,
                "headers": cors_headers(),
                "body": json.dumps({"error": "Not Found"}),
            }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": cors_headers(),
            "body": json.dumps({"error": "Internal Server Error"}),
        }


def create_task(event):
    """新しいタスクを作成"""
    body = json.loads(event["body"])

    # バリデーション
    if not body.get("title") or not body.get("user_id"):
        return {
            "statusCode": 400,
            "headers": cors_headers(),
            "body": json.dumps({"error": "title and user_id are required"}),
        }

    # タスクデータ準備
    task_id = str(uuid.uuid4())
    task = {
        "task_id": task_id,
        "user_id": body["user_id"],
        "title": body["title"],
        "description": body.get("description", ""),
        "status": "pending",
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }

    # DynamoDBに保存
    table = dynamodb.Table(DYNAMODB_TABLE)
    table.put_item(Item=task)

    return {
        "statusCode": 201,
        "headers": cors_headers(),
        "body": json.dumps(task, default=decimal_default),
    }


def get_tasks(event):
    """ユーザーのタスク一覧を取得"""
    user_id = (
        event["queryStringParameters"].get("user_id")
        if event.get("queryStringParameters")
        else None
    )

    if not user_id:
        return {
            "statusCode": 400,
            "headers": cors_headers(),
            "body": json.dumps({"error": "user_id parameter is required"}),
        }

    table = dynamodb.Table(DYNAMODB_TABLE)
    response = table.query(
        IndexName="user-id-index",
        KeyConditionExpression="user_id = :user_id",
        ExpressionAttributeValues={":user_id": user_id},
    )

    return {
        "statusCode": 200,
        "headers": cors_headers(),
        "body": json.dumps(response["Items"], default=decimal_default),
    }


def get_task(event):
    """特定のタスクを取得"""
    task_id = event["pathParameters"]["task_id"]

    table = dynamodb.Table(DYNAMODB_TABLE)
    response = table.get_item(Key={"task_id": task_id})

    if "Item" not in response:
        return {
            "statusCode": 404,
            "headers": cors_headers(),
            "body": json.dumps({"error": "Task not found"}),
        }

    return {
        "statusCode": 200,
        "headers": cors_headers(),
        "body": json.dumps(response["Item"], default=decimal_default),
    }


def update_task(event):
    """タスクを更新"""
    task_id = event["pathParameters"]["task_id"]
    body = json.loads(event["body"])

    table = dynamodb.Table(DYNAMODB_TABLE)

    # 更新可能フィールド
    update_expression = "SET updated_at = :updated_at"
    expression_values = {":updated_at": datetime.utcnow().isoformat()}

    if "title" in body:
        update_expression += ", title = :title"
        expression_values[":title"] = body["title"]

    if "description" in body:
        update_expression += ", description = :description"
        expression_values[":description"] = body["description"]

    if "status" in body:
        update_expression += ", #status = :status"
        expression_values[":status"] = body["status"]

    try:
        response = table.update_item(
            Key={"task_id": task_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ExpressionAttributeNames=(
                {"#status": "status"} if "status" in body else {}
            ),
            ReturnValues="ALL_NEW",
        )

        return {
            "statusCode": 200,
            "headers": cors_headers(),
            "body": json.dumps(
                response["Attributes"], default=decimal_default
            ),
        }
    except Exception as e:
        return {
            "statusCode": 404,
            "headers": cors_headers(),
            "body": json.dumps({"error": "Task not found"}),
        }


def delete_task(event):
    """タスクを削除"""
    task_id = event["pathParameters"]["task_id"]

    table = dynamodb.Table(DYNAMODB_TABLE)
    try:
        table.delete_item(
            Key={"task_id": task_id},
            ConditionExpression="attribute_exists(task_id)",
        )

        return {"statusCode": 204, "headers": cors_headers(), "body": ""}
    except Exception as e:
        return {
            "statusCode": 404,
            "headers": cors_headers(),
            "body": json.dumps({"error": "Task not found"}),
        }


def generate_report(event):
    """レポート生成をSQSにキューイング"""
    body = json.loads(event["body"])
    user_id = body.get("user_id")

    if not user_id:
        return {
            "statusCode": 400,
            "headers": cors_headers(),
            "body": json.dumps({"error": "user_id is required"}),
        }

    # SQSにメッセージを送信
    message = {
        "type": "generate_report",
        "user_id": user_id,
        "requested_at": datetime.utcnow().isoformat(),
    }

    sqs.send_message(QueueUrl=SQS_QUEUE_URL, MessageBody=json.dumps(message))

    return {
        "statusCode": 202,
        "headers": cors_headers(),
        "body": json.dumps(
            {"message": "Report generation started", "user_id": user_id}
        ),
    }


def cors_headers():
    """CORS ヘッダー"""
    return {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key",
    }


def decimal_default(obj):
    """DynamoDB Decimal型をJSONシリアライズ用に変換"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError
