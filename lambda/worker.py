import json
import boto3
import os
from datetime import datetime

# 環境変数から設定を取得
DYNAMODB_TABLE = os.environ.get("DYNAMODB_TABLE")
S3_BUCKET = os.environ.get("S3_BUCKET")

# AWSクライアント初期化
dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")


def lambda_handler(event, context):
    """
    SQSメッセージを処理してレポートを生成
    """
    try:
        for record in event["Records"]:
            message = json.loads(record["body"])

            if message["type"] == "generate_report":
                generate_user_report(message["user_id"])

    except Exception as e:
        print(f"Error processing message: {str(e)}")
        raise


def generate_user_report(user_id):
    """
    ユーザーのタスクレポートを生成してS3に保存
    """
    print(f"Generating report for user: {user_id}")

    # DynamoDBからユーザーのタスクを取得
    table = dynamodb.Table(DYNAMODB_TABLE)
    response = table.query(
        IndexName="user-id-index",
        KeyConditionExpression="user_id = :user_id",
        ExpressionAttributeValues={":user_id": user_id},
    )

    tasks = response["Items"]

    # レポートデータを生成
    report = generate_report_data(user_id, tasks)

    # S3にレポートを保存
    report_key = f"reports/{user_id}/{datetime.utcnow().strftime('%Y-%m-%d')}_report.json"

    s3.put_object(
        Bucket=S3_BUCKET,
        Key=report_key,
        Body=json.dumps(report, indent=2, default=str),
        ContentType="application/json",
    )

    print(f"Report saved to s3://{S3_BUCKET}/{report_key}")


def generate_report_data(user_id, tasks):
    """
    タスクデータからレポートを生成
    """
    # ステータス別集計
    status_counts = {}
    for task in tasks:
        status = task.get("status", "unknown")
        status_counts[status] = status_counts.get(status, 0) + 1

    # 今日作成されたタスク数
    today = datetime.utcnow().date().isoformat()
    today_tasks = [
        task for task in tasks if task.get("created_at", "").startswith(today)
    ]

    # レポートデータ
    report = {
        "user_id": user_id,
        "generated_at": datetime.utcnow().isoformat(),
        "summary": {
            "total_tasks": len(tasks),
            "status_breakdown": status_counts,
            "today_created": len(today_tasks),
        },
        "tasks": tasks,
    }

    return report
