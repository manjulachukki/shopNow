#!/bin/bash
# CloudWatch Alarms for ShopNow Application
# Run this script with AWS CLI configured and appropriate permissions
#
# Usage: bash create-alarms.sh [--sns-topic-arn <arn>]
#
# Prerequisites:
#   - AWS CLI configured with permissions for cloudwatch:PutMetricAlarm
#   - Optional: SNS topic for alarm notifications

set -e

AWS_REGION="us-east-1"
CLUSTER_NAME="manjula-eks-cluster-shopnow"
NAMESPACE="shopnow-demo"
SNS_TOPIC_ARN="${1:-}"

ALARM_ACTIONS=""
if [ -n "$SNS_TOPIC_ARN" ]; then
  ALARM_ACTIONS="--alarm-actions $SNS_TOPIC_ARN --ok-actions $SNS_TOPIC_ARN"
fi

echo "=== Creating CloudWatch Alarms for ShopNow ==="

# -------------------------------------------------------
# 1. Backend Pod CPU Utilization > 80%
# -------------------------------------------------------
echo "Creating alarm: shopnow-backend-high-cpu"
aws cloudwatch put-metric-alarm \
  --alarm-name "shopnow-backend-high-cpu" \
  --alarm-description "Backend pod CPU utilization exceeds 80%" \
  --namespace "ContainerInsights" \
  --metric-name "pod_cpu_utilization" \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} Name=Namespace,Value=${NAMESPACE} Name=PodName,Value=shopnow-backend \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --treat-missing-data missing \
  --region ${AWS_REGION} \
  ${ALARM_ACTIONS}

# -------------------------------------------------------
# 2. Backend Pod Memory Utilization > 80%
# -------------------------------------------------------
echo "Creating alarm: shopnow-backend-high-memory"
aws cloudwatch put-metric-alarm \
  --alarm-name "shopnow-backend-high-memory" \
  --alarm-description "Backend pod memory utilization exceeds 80%" \
  --namespace "ContainerInsights" \
  --metric-name "pod_memory_utilization" \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} Name=Namespace,Value=${NAMESPACE} Name=PodName,Value=shopnow-backend \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --treat-missing-data missing \
  --region ${AWS_REGION} \
  ${ALARM_ACTIONS}

# -------------------------------------------------------
# 3. Frontend Pod Restart Count > 3
# -------------------------------------------------------
echo "Creating alarm: shopnow-frontend-pod-restarts"
aws cloudwatch put-metric-alarm \
  --alarm-name "shopnow-frontend-pod-restarts" \
  --alarm-description "Frontend pod restarted more than 3 times in 10 min" \
  --namespace "ContainerInsights" \
  --metric-name "pod_number_of_container_restarts" \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} Name=Namespace,Value=${NAMESPACE} Name=PodName,Value=shopnow-frontend \
  --statistic Maximum \
  --period 600 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --treat-missing-data missing \
  --region ${AWS_REGION} \
  ${ALARM_ACTIONS}

# -------------------------------------------------------
# 4. Backend Pod Restart Count > 3
# -------------------------------------------------------
echo "Creating alarm: shopnow-backend-pod-restarts"
aws cloudwatch put-metric-alarm \
  --alarm-name "shopnow-backend-pod-restarts" \
  --alarm-description "Backend pod restarted more than 3 times in 10 min" \
  --namespace "ContainerInsights" \
  --metric-name "pod_number_of_container_restarts" \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} Name=Namespace,Value=${NAMESPACE} Name=PodName,Value=shopnow-backend \
  --statistic Maximum \
  --period 600 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --treat-missing-data missing \
  --region ${AWS_REGION} \
  ${ALARM_ACTIONS}

# -------------------------------------------------------
# 5. Node CPU Utilization > 85%
# -------------------------------------------------------
echo "Creating alarm: shopnow-node-high-cpu"
aws cloudwatch put-metric-alarm \
  --alarm-name "shopnow-node-high-cpu" \
  --alarm-description "EKS node CPU utilization exceeds 85%" \
  --namespace "ContainerInsights" \
  --metric-name "node_cpu_utilization" \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} \
  --statistic Average \
  --period 300 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 3 \
  --treat-missing-data missing \
  --region ${AWS_REGION} \
  ${ALARM_ACTIONS}

# -------------------------------------------------------
# 6. Node Memory Utilization > 85%
# -------------------------------------------------------
echo "Creating alarm: shopnow-node-high-memory"
aws cloudwatch put-metric-alarm \
  --alarm-name "shopnow-node-high-memory" \
  --alarm-description "EKS node memory utilization exceeds 85%" \
  --namespace "ContainerInsights" \
  --metric-name "node_memory_utilization" \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} \
  --statistic Average \
  --period 300 \
  --threshold 85 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 3 \
  --treat-missing-data missing \
  --region ${AWS_REGION} \
  ${ALARM_ACTIONS}

# -------------------------------------------------------
# 7. Running Pod Count < 1 (Backend down)
# -------------------------------------------------------
echo "Creating alarm: shopnow-backend-no-pods"
aws cloudwatch put-metric-alarm \
  --alarm-name "shopnow-backend-no-pods" \
  --alarm-description "Backend has zero running pods" \
  --namespace "ContainerInsights" \
  --metric-name "pod_number_of_running_pods" \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} Name=Namespace,Value=${NAMESPACE} Name=Service,Value=shopnow-backend \
  --statistic Minimum \
  --period 60 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 2 \
  --treat-missing-data breaching \
  --region ${AWS_REGION} \
  ${ALARM_ACTIONS}

# -------------------------------------------------------
# 8. Backend Error Logs (log-based metric filter)
# -------------------------------------------------------
echo "Creating log metric filter: shopnow-backend-errors"
aws logs put-metric-filter \
  --log-group-name "/eks/${CLUSTER_NAME}/shopnow-app" \
  --filter-name "shopnow-backend-errors" \
  --filter-pattern '{ $.log_processed.level = "error" || $.log = "*Error*" || $.log = "*error*" }' \
  --metric-transformations \
    metricName=BackendErrorCount,metricNamespace=ShopNow/Application,metricValue=1,defaultValue=0 \
  --region ${AWS_REGION} || echo "WARN: Could not create metric filter (log group may not exist yet)"

echo "Creating alarm: shopnow-backend-error-rate"
aws cloudwatch put-metric-alarm \
  --alarm-name "shopnow-backend-error-rate" \
  --alarm-description "Backend error log count exceeds 10 in 5 min" \
  --namespace "ShopNow/Application" \
  --metric-name "BackendErrorCount" \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --treat-missing-data notBreaching \
  --region ${AWS_REGION} \
  ${ALARM_ACTIONS}

echo ""
echo "=== All alarms created successfully ==="
echo ""
echo "View alarms: https://${AWS_REGION}.console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#alarmsV2:"
echo ""
echo "To receive notifications, create an SNS topic and re-run:"
echo "  bash create-alarms.sh --sns-topic-arn arn:aws:sns:${AWS_REGION}:975050024946:shopnow-alerts"
