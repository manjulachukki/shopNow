# CloudWatch Monitoring & Logging for ShopNow

## Architecture

```
EKS Cluster (manjula-eks-cluster-shopnow)
├── shopnow-demo namespace
│   ├── backend (Node.js)    ─┐
│   ├── frontend (Nginx)      ├── Application Logs → Fluent Bit → CloudWatch Logs
│   ├── admin (Nginx)         │
│   └── mongo (StatefulSet)  ─┘
│
└── amazon-cloudwatch namespace
    ├── CloudWatch Agent (DaemonSet)  → Container Insights Metrics
    └── Fluent Bit (DaemonSet)        → CloudWatch Logs
```

## Prerequisites

1. **IAM OIDC Provider** for the EKS cluster (for IRSA – IAM Roles for Service Accounts)
2. **IAM Policy** attached to the node role or service account with:
   - `CloudWatchAgentServerPolicy`
   - `CloudWatchLogsFullAccess`

### Attach IAM Policy to Node Group Role

```bash
# Find your node group IAM role
NODE_ROLE=$(aws eks describe-nodegroup \
  --cluster-name manjula-eks-cluster-shopnow \
  --nodegroup-name <your-nodegroup-name> \
  --query 'nodegroup.nodeRole' --output text --region us-east-1)

# Attach CloudWatch policies
aws iam attach-role-policy --role-name $(basename $NODE_ROLE) \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

aws iam attach-role-policy --role-name $(basename $NODE_ROLE) \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
```

## Deployment Steps

### Step 1: Create Namespace

```bash
kubectl apply -f kubernetes/monitoring/namespace.yaml
```

### Step 2: Deploy CloudWatch Agent (Metrics)

Collects **Container Insights** metrics (CPU, memory, disk, network) from all pods and nodes.

```bash
kubectl apply -f kubernetes/monitoring/cloudwatch-agent.yaml
```

Verify:
```bash
kubectl get daemonset cloudwatch-agent -n amazon-cloudwatch
kubectl logs -l app=cloudwatch-agent -n amazon-cloudwatch --tail=20
```

### Step 3: Deploy Fluent Bit (Logs)

Collects logs from all ShopNow containers and ships them to CloudWatch Logs.

```bash
kubectl apply -f kubernetes/monitoring/fluent-bit.yaml
```

Verify:
```bash
kubectl get daemonset fluent-bit -n amazon-cloudwatch
kubectl logs -l app=fluent-bit -n amazon-cloudwatch --tail=20
```

### Step 4: Create CloudWatch Alarms

```bash
# Without SNS notifications
bash kubernetes/monitoring/create-alarms.sh

# With SNS email notifications
bash kubernetes/monitoring/create-alarms.sh arn:aws:sns:us-east-1:975050024946:shopnow-alerts
```

## CloudWatch Log Groups

| Log Group | Contents |
|-----------|----------|
| `/eks/manjula-eks-cluster-shopnow/shopnow-app` | All ShopNow application logs (backend, frontend, admin, mongo) |
| `/eks/manjula-eks-cluster-shopnow/kube-system` | Kubernetes system component logs |

## CloudWatch Alarms Summary

| Alarm | Metric | Threshold | Period |
|-------|--------|-----------|--------|
| `shopnow-backend-high-cpu` | Pod CPU utilization | > 80% | 5 min (2 eval) |
| `shopnow-backend-high-memory` | Pod memory utilization | > 80% | 5 min (2 eval) |
| `shopnow-frontend-pod-restarts` | Container restarts | > 3 | 10 min |
| `shopnow-backend-pod-restarts` | Container restarts | > 3 | 10 min |
| `shopnow-node-high-cpu` | Node CPU utilization | > 85% | 5 min (3 eval) |
| `shopnow-node-high-memory` | Node memory utilization | > 85% | 5 min (3 eval) |
| `shopnow-backend-no-pods` | Running pod count | < 1 | 1 min (2 eval) |
| `shopnow-backend-error-rate` | Error log count | > 10 | 5 min |

## Viewing in AWS Console

- **Metrics**: CloudWatch → Container Insights → Performance Monitoring
- **Logs**: CloudWatch → Log Groups → `/eks/manjula-eks-cluster-shopnow/`
- **Alarms**: CloudWatch → Alarms → All alarms

## Optional: SNS Email Notifications

```bash
# Create SNS topic
aws sns create-topic --name shopnow-alerts --region us-east-1

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:975050024946:shopnow-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com \
  --region us-east-1

# Confirm subscription via the email link, then re-run alarms script
bash kubernetes/monitoring/create-alarms.sh arn:aws:sns:us-east-1:975050024946:shopnow-alerts
```
