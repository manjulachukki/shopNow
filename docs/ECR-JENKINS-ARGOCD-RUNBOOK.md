# ShopNow ECR + Jenkins + Argo CD Runbook

## Goal
Build ShopNow images, push them to AWS ECR with `manjula` naming, and align Jenkins, Helm, Kubernetes manifests, and Argo CD to deploy those images.

## Environment Used
- AWS Account: `975050024946`
- AWS Region: `us-east-1`
- ECR Registry: `975050024946.dkr.ecr.us-east-1.amazonaws.com`
- Image repos:
  - `manjula-shopnow-frontend`
  - `manjula-shopnow-backend`
  - `manjula-shopnow-admin`

## 1. Build Docker Images Locally
From repo root:

```powershell
docker build -t shopnow-admin:local ./admin
docker build -t shopnow-backend:local ./backend
docker build -t shopnow-frontend:local ./frontend
```

## 2. Fix Frontend Docker Build Issue
Issue seen: `react-scripts: not found` during `frontend` image build.

Fix applied in `frontend/Dockerfile`:
- Set npm TLS behavior for corporate/intercepted SSL environments.
- Added npm retry settings.
- Kept `npm ci` in builder stage and validated `react-scripts` binary.

Result: frontend image build succeeds.

## 3. Verify AWS and ECR Access
```powershell
aws --version
docker --version
aws sts get-caller-identity
aws configure get region
aws ecr describe-repositories --query "repositories[].repositoryName" --output text
```

## 4. Create/Verify ECR Repositories
Create if missing:

```powershell
aws ecr create-repository --repository-name manjula-shopnow-frontend
aws ecr create-repository --repository-name manjula-shopnow-backend
aws ecr create-repository --repository-name manjula-shopnow-admin
```

## 5. Login to ECR
```powershell
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 975050024946.dkr.ecr.us-east-1.amazonaws.com
```

## 6. Tag and Push Images
### Push `latest`
```powershell
docker tag shopnow-frontend:local 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-frontend:latest
docker push 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-frontend:latest

docker tag shopnow-backend:local 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-backend:latest
docker push 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-backend:latest

docker tag shopnow-admin:local 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-admin:latest
docker push 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-admin:latest
```

### Push `v1.0.0` (optional/versioned)
```powershell
docker tag shopnow-frontend:local 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-frontend:v1.0.0
docker push 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-frontend:v1.0.0

docker tag shopnow-backend:local 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-backend:v1.0.0
docker push 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-backend:v1.0.0

docker tag shopnow-admin:local 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-admin:v1.0.0
docker push 975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-admin:v1.0.0
```

## 7. Verify ECR Images
```powershell
aws ecr list-images --region us-east-1 --repository-name manjula-shopnow-frontend --query "imageIds[].imageTag" --output text
aws ecr list-images --region us-east-1 --repository-name manjula-shopnow-backend --query "imageIds[].imageTag" --output text
aws ecr list-images --region us-east-1 --repository-name manjula-shopnow-admin --query "imageIds[].imageTag" --output text
```

To verify exact `latest` details:
```powershell
aws ecr describe-images --region us-east-1 --repository-name manjula-shopnow-frontend --image-ids imageTag=latest --output json
```

## 8. Update Helm Chart Values
Updated image repositories in:
- `kubernetes/helm/charts/frontend/values.yaml`
- `kubernetes/helm/charts/backend/values.yaml`
- `kubernetes/helm/charts/admin/values.yaml`

Set to:
- `975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-frontend`
- `975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-backend`
- `975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-admin`

## 9. Update Raw K8s Deployment Manifests
Updated image fields in:
- `kubernetes/k8s-manifests/frontend/deployment.yaml`
- `kubernetes/k8s-manifests/backend/deployment.yaml`
- `kubernetes/k8s-manifests/admin/deployment.yaml`

All now point to `us-east-1` + `manjula-shopnow-*` + `:latest`.

## 10. Update Jenkins Pipelines
### CI Jenkinsfiles updated
- `jenkins/Jenkinsfile.ci.frontend`
- `jenkins/Jenkinsfile.ci.backend`
- `jenkins/Jenkinsfile.ci.admin`

Changes:
- Use AWS ECR login (`aws ecr get-login-password ...`).
- Push commit-tagged image and `latest`.
- Use repos `manjula-shopnow-*`.
- Region/account set to `us-east-1` / `975050024946`.

### CD Jenkinsfiles updated
- `jenkins/Jenkinsfile.cd.frontend`
- `jenkins/Jenkinsfile.cd.backend`
- `jenkins/Jenkinsfile.cd.admin`

Changes:
- Correct chart paths:
  - `kubernetes/helm/charts/frontend`
  - `kubernetes/helm/charts/backend`
  - `kubernetes/helm/charts/admin`
- Explicit image repository override to ECR `manjula-shopnow-*`.
- Rollout status check fixed to `deployment/${RELEASE_NAME}`.

## 11. Jenkins Credentials Needed
Create these in Jenkins:
- `aws-jenkins-cred` (AWS credential)
- `kubeconfig-credential` (file credential for kubeconfig)

Jenkins agent tools required:
- `docker`
- `aws`
- `helm`
- `kubectl`

## 12. Update Argo CD Applications
Updated:
- `kubernetes/argocd/apps/frontend-app.yaml`
- `kubernetes/argocd/apps/backend-app.yaml`
- `kubernetes/argocd/apps/admin-app.yaml`

Added Helm parameters:
- `image.repository` -> `975050024946.dkr.ecr.us-east-1.amazonaws.com/manjula-shopnow-*`
- `image.tag` -> `latest`

This makes Argo CD image selection explicit and consistent with Jenkins/ECR.

## 13. Useful Console URLs
- Frontend:
  - `https://us-east-1.console.aws.amazon.com/ecr/repositories/private/975050024946/manjula-shopnow-frontend?region=us-east-1`
- Backend:
  - `https://us-east-1.console.aws.amazon.com/ecr/repositories/private/975050024946/manjula-shopnow-backend?region=us-east-1`
- Admin:
  - `https://us-east-1.console.aws.amazon.com/ecr/repositories/private/975050024946/manjula-shopnow-admin?region=us-east-1`

## 14. Troubleshooting Notes
- If image not visible in console, check:
  1. Correct account (`975050024946`)
  2. Correct region (`us-east-1`)
  3. ECR Private (not Public)
  4. Console filters
- If frontend build fails with `react-scripts: not found`, verify frontend Dockerfile npm TLS/retry settings and `npm ci` step.
