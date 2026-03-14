# ShopNow - ChatOps Integration with AWS SNS

Set up notifications for build, deployment, and monitoring events using Amazon SNS integrated with Email, Slack, and Jenkins.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  EVENT SOURCES                       │
│                                                     │
│  Jenkins Build ──┐                                  │
│  Helm Deploy ────┤    aws sns publish               │
│  CW Alarms ──────┘         │                        │
└────────────────────────────┼────────────────────────┘
                             ▼
                    ┌─────────────────┐
                    │   SNS Topics    │
                    │                 │
                    │  shopnow-builds │
                    │  shopnow-deploy │
                    │  shopnow-alerts │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
         ┌────────┐   ┌──────────┐   ┌──────────┐
         │ Email  │   │  Lambda  │   │   SMS    │
         │        │   │  ↓       │   │          │
         │ Inbox  │   │  Slack   │   │  Phone   │
         └────────┘   └──────────┘   └──────────┘
```

## What is SNS?

**Amazon SNS (Simple Notification Service)** is a managed message broadcasting service. When an event happens (build success, deployment failure, alarm triggered), SNS sends a notification to all subscribers — via email, Slack, SMS, or any webhook.

---

## Step 1: Create SNS Topics

Create separate topics for different event types:

```bash
AWS_REGION="us-east-1"

# Deployment notifications
aws sns create-topic --name shopnow-deployments --region $AWS_REGION

# Build notifications
aws sns create-topic --name shopnow-builds --region $AWS_REGION

# Monitoring/alarm notifications
aws sns create-topic --name shopnow-alerts --region $AWS_REGION

# Verify topics were created
aws sns list-topics --region $AWS_REGION
```

Each topic returns an ARN like:

```
arn:aws:sns:us-east-1:975050024946:shopnow-deployments
```

---

## Step 2: Subscribe to Topics

### Email Notifications

```bash
# Subscribe to deployment events
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:975050024946:shopnow-deployments \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --region us-east-1

# Subscribe to build events
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:975050024946:shopnow-builds \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --region us-east-1

# Subscribe to alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:975050024946:shopnow-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --region us-east-1
```

> **Important:** Check your email and click the **confirmation link** — SNS won't send notifications until you confirm.

### SMS Notifications

```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:975050024946:shopnow-alerts \
  --protocol sms \
  --notification-endpoint "+1234567890" \
  --region us-east-1
```

---

## Step 3: Integrate with Slack

### 3a. Create Slack Incoming Webhook

1. Go to https://api.slack.com/apps → **Create New App**
2. Choose **From scratch** → name it "ShopNow Notifications"
3. Select your workspace
4. Go to **Incoming Webhooks** → Turn it **On**
5. Click **Add New Webhook to Workspace** → select a channel (e.g., `#shopnow-alerts`)
6. Copy the webhook URL (looks like `https://hooks.slack.com/services/T00/B00/xxxx`)

### 3b. Create Lambda Function (SNS → Slack Bridge)

Create this Lambda function in the AWS Console:

- **Runtime:** Python 3.12
- **Function name:** `shopnow-sns-to-slack`

```python
import json
import os
from urllib.request import Request, urlopen

SLACK_WEBHOOK_URL = os.environ['SLACK_WEBHOOK_URL']

def lambda_handler(event, context):
    for record in event['Records']:
        sns_message = record['Sns']
        subject = sns_message.get('Subject', 'ShopNow Notification')
        message = sns_message.get('Message', '')
        topic_arn = sns_message.get('TopicArn', '')

        # Determine emoji based on topic
        if 'alert' in topic_arn.lower():
            emoji = ':rotating_light:'
            color = '#FF0000'
        elif 'deployment' in topic_arn.lower():
            emoji = ':rocket:'
            color = '#36A64F'
        else:
            emoji = ':hammer_and_wrench:'
            color = '#439FE0'

        # Format Slack message
        slack_payload = {
            "attachments": [
                {
                    "color": color,
                    "title": f"{emoji} {subject}",
                    "text": message,
                    "footer": "ShopNow CI/CD"
                }
            ]
        }

        req = Request(
            SLACK_WEBHOOK_URL,
            data=json.dumps(slack_payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )
        urlopen(req)

    return {'statusCode': 200}
```

### 3c. Set Lambda Environment Variable

In Lambda → Configuration → Environment variables:

| Key | Value |
|-----|-------|
| `SLACK_WEBHOOK_URL` | `https://hooks.slack.com/services/T00/B00/xxxx` |

### 3d. Add SNS Trigger Permission

```bash
LAMBDA_ARN="arn:aws:lambda:us-east-1:975050024946:function:shopnow-sns-to-slack"

# Allow SNS to invoke the Lambda
aws lambda add-permission \
  --function-name shopnow-sns-to-slack \
  --statement-id sns-builds \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn arn:aws:sns:us-east-1:975050024946:shopnow-builds \
  --region us-east-1

aws lambda add-permission \
  --function-name shopnow-sns-to-slack \
  --statement-id sns-deployments \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn arn:aws:sns:us-east-1:975050024946:shopnow-deployments \
  --region us-east-1

aws lambda add-permission \
  --function-name shopnow-sns-to-slack \
  --statement-id sns-alerts \
  --action lambda:InvokeFunction \
  --principal sns.amazonaws.com \
  --source-arn arn:aws:sns:us-east-1:975050024946:shopnow-alerts \
  --region us-east-1
```

### 3e. Subscribe Lambda to SNS Topics

```bash
LAMBDA_ARN="arn:aws:lambda:us-east-1:975050024946:function:shopnow-sns-to-slack"

aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:975050024946:shopnow-builds \
  --protocol lambda \
  --notification-endpoint $LAMBDA_ARN \
  --region us-east-1

aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:975050024946:shopnow-deployments \
  --protocol lambda \
  --notification-endpoint $LAMBDA_ARN \
  --region us-east-1

aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:975050024946:shopnow-alerts \
  --protocol lambda \
  --notification-endpoint $LAMBDA_ARN \
  --region us-east-1
```

---

## Step 4: Connect CloudWatch Alarms to SNS

Use the existing alarms script with the alerts topic ARN:

```bash
bash kubernetes/monitoring/create-alarms.sh \
    arn:aws:sns:us-east-1:975050024946:shopnow-alerts
```

This connects all 8 CloudWatch alarms (CPU, memory, pod restarts, etc.) to send notifications when triggered.

---

## Step 5: Test Notifications

Send a test message:

```bash
aws sns publish \
    --topic-arn "arn:aws:sns:us-east-1:975050024946:shopnow-builds" \
    --subject "TEST: ShopNow Notification" \
    --message "This is a test notification from ShopNow ChatOps setup." \
    --region us-east-1
```

You should receive the notification via all subscribed channels (email, Slack, SMS).

---

## Summary

| SNS Topic | Event Source | Purpose |
|-----------|-------------|---------|
| `shopnow-builds` | Jenkins `post` block | Build success/failure |
| `shopnow-deployments` | Jenkins deploy stages | Deployment success/failure |
| `shopnow-alerts` | CloudWatch Alarms | CPU/memory/restart/error alerts |

| Subscriber | Protocol | Setup |
|------------|----------|-------|
| Email | `email` | Direct SNS subscription |
| SMS | `sms` | Direct SNS subscription |
| Slack | `lambda` | SNS → Lambda → Slack webhook |
