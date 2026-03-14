# ShopNow - Verification Guide

How to verify that frontend, backend, admin, and database are functional and accessible after deployment.

## Prerequisites

- `kubectl` configured with EKS access
- Kubeconfig generated:
  ```bash
  aws eks update-kubeconfig --name manjula-eks-cluster-shopnow --region us-east-1
  ```

---

## Step 1: Check Pods Are Running

```bash
kubectl get pods -n shopnow-demo -o wide
```

**Expected:** All pods show `STATUS: Running` and `READY: 1/1`

```
NAME                        READY   STATUS    RESTARTS
shopnow-backend-xxx         1/1     Running   0
shopnow-frontend-xxx        1/1     Running   0
shopnow-admin-xxx           1/1     Running   0
mongo-0                     1/1     Running   0
```

---

## Step 2: Check Services

```bash
kubectl get svc -n shopnow-demo
```

**Expected:**

| Service    | Type      | Port |
|------------|-----------|------|
| frontend   | ClusterIP | 80   |
| backend    | ClusterIP | 5000 |
| admin      | ClusterIP | 80   |
| mongo-headless | ClusterIP (None) | 27017 |

---

## Step 3: Check Ingress & Get External URL

```bash
kubectl get ingress -n shopnow-demo
```

**Expected:** Shows an `ADDRESS` column with the load balancer hostname.

---

## Step 4: Test Backend Health (In-Cluster)

**Option A: Port-forward to localhost**

```bash
kubectl port-forward svc/backend 5000:5000 -n shopnow-demo
```

Then in another terminal:

```bash
curl http://localhost:5000/api/health
```

**Option B: Exec into a pod**

```bash
kubectl exec -it deploy/shopnow-frontend -n shopnow-demo -- wget -qO- http://backend:5000/api/health
```

**Expected:** JSON response like `{"status":"ok"}`

---

## Step 5: Test Frontend (Port-Forward)

```bash
kubectl port-forward svc/frontend 3000:80 -n shopnow-demo
```

Open **http://localhost:3000** in your browser. You should see the ShopNow store page.

---

## Step 6: Test Admin Panel (Port-Forward)

```bash
kubectl port-forward svc/admin 3001:80 -n shopnow-demo
```

Open **http://localhost:3001** in your browser. You should see the ShopNow admin dashboard.

---

## Step 7: Test via Ingress (External Access)

Get the load balancer address:

```bash
INGRESS_URL=$(kubectl get ingress shopnow-ingress -n shopnow-demo \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $INGRESS_URL
```

Test each endpoint:

```bash
# Frontend — expected: 200
curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_URL/aryan

# Admin — expected: 200
curl -s -o /dev/null -w "%{http_code}" http://$INGRESS_URL/aryan-admin

# Backend API health — expected: JSON response
curl http://$INGRESS_URL/aryan/api/health
```

**Or open in browser:**

- Frontend: `http://<INGRESS_URL>/aryan`
- Admin: `http://<INGRESS_URL>/aryan-admin`

---

## Step 8: Verify MongoDB Connectivity

```bash
kubectl exec -it mongo-0 -n shopnow-demo -- mongosh --eval "db.adminCommand('ping')"
```

**Expected:** `{ ok: 1 }`

---

## Step 9: Check HPA (Autoscaling)

```bash
kubectl get hpa -n shopnow-demo
```

**Expected:** Shows min/max replicas and current CPU utilization for backend, frontend, and admin.

---

## Step 10: Check Pod Logs (Troubleshooting)

```bash
# Backend logs
kubectl logs -l app=backend -n shopnow-demo --tail=50

# Frontend logs
kubectl logs -l app=frontend -n shopnow-demo --tail=50

# Admin logs
kubectl logs -l app=admin -n shopnow-demo --tail=50

# MongoDB logs
kubectl logs mongo-0 -n shopnow-demo --tail=50
```

---

## Quick All-in-One Verification Script

```bash
#!/bin/bash
NS="shopnow-demo"

echo "=== Pods ==="
kubectl get pods -n $NS

echo ""
echo "=== Services ==="
kubectl get svc -n $NS

echo ""
echo "=== Ingress ==="
kubectl get ingress -n $NS

echo ""
echo "=== Backend Health (in-cluster) ==="
kubectl exec deploy/shopnow-backend -n $NS -- \
  wget -qO- --timeout=5 http://localhost:5000/api/health 2>/dev/null || echo "FAIL"

echo ""
echo "=== Frontend Health (in-cluster) ==="
kubectl exec deploy/shopnow-frontend -n $NS -- \
  wget -qO- --timeout=5 http://localhost/health 2>/dev/null || echo "FAIL"

echo ""
echo "=== Admin Health (in-cluster) ==="
kubectl exec deploy/shopnow-admin -n $NS -- \
  wget -qO- --timeout=5 http://localhost/health 2>/dev/null || echo "FAIL"

echo ""
echo "=== MongoDB Ping ==="
kubectl exec mongo-0 -n $NS -- mongosh --quiet --eval "db.adminCommand('ping')" 2>/dev/null || echo "FAIL"

echo ""
echo "=== HPA Status ==="
kubectl get hpa -n $NS

echo ""
echo "=== All checks complete ==="
```

Save this as `verify.sh` and run:

```bash
chmod +x verify.sh
./verify.sh
```

---

## Verification Checklist

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | Pods running | `kubectl get pods -n shopnow-demo` | All `1/1 Running` |
| 2 | Services exist | `kubectl get svc -n shopnow-demo` | 4 services listed |
| 3 | Ingress has address | `kubectl get ingress -n shopnow-demo` | ADDRESS populated |
| 4 | Backend health | `curl localhost:5000/api/health` | `{"status":"ok"}` |
| 5 | Frontend loads | Browser → `localhost:3000` | ShopNow store page |
| 6 | Admin loads | Browser → `localhost:3001` | Admin dashboard |
| 7 | External frontend | `curl http://<LB>/aryan` | HTTP 200 |
| 8 | External admin | `curl http://<LB>/aryan-admin` | HTTP 200 |
| 9 | MongoDB ping | `mongosh --eval "db.adminCommand('ping')"` | `{ ok: 1 }` |
| 10 | HPA active | `kubectl get hpa -n shopnow-demo` | Shows targets |
