# SRE-DEMO-SRE-Pretest
# SRE-Pretest, candidate Lam Kin Kwan

# SRE Pretest — Deploy to EKS via HELM

## Architecture Overview

```
Internet
    └── AWS NLB (Network Load Balancer)   ← provisioned automatically by K8s Service
            └── EKS Worker Nodes (Private Subnet, 3 AZs)
                    └── sre-demo-app Pods (nginx, port 8080)
                            └── /sre.txt → "Hello SRE!"
```

---

## File Structure

```
charts/sre-demo-app/
├── Chart.yaml              # Helm chart metadata (name, version, appVersion)
├── values.yaml             # All configurable parameters (image, replicas, HPA, resources)
└── templates/
    ├── _helpers.tpl        # Reusable named templates (fullname helper)
    ├── deployment.yaml     # K8s Deployment with liveness/readiness probes
    └── service.yaml        # K8s Service (LoadBalancer → AWS NLB)

kubernetes/                 # Plain manifest alternative (no Helm required)
├── deployment.yaml
└── service.yaml
```

---

## Prerequisites

```bash
# Verify tools are installed
terraform --version    # >= 1.0.0
kubectl version        # client + server
helm version           # >= 3.0
aws --version

# Confirm kubectl is pointed at the right cluster
kubectl config current-context

# If not, update kubeconfig
aws eks update-kubeconfig \
  --region ap-southeast-1 \
  --name <cluster_name>
```

---

## Step 1 — Authenticate to ECR and Push Image

```bash
# Login to ECR
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com

# Tag the image built in Topic 2
docker tag sre-nginx:latest \
  <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/sre-demo-nginx:latest

# Push to ECR
docker push \
  <YOUR_AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/sre-demo-nginx:latest
```

---

## Step 2A — Deploy via Helm (recommended)

```bash
# Lint the chart first (catch template errors before deploying)
helm lint charts/sre-demo-app

# Dry-run to preview rendered manifests
helm install sre-demo-app charts/sre-demo-app --dry-run --debug

# Install
helm install sre-demo-app charts/sre-demo-app

# If already installed, upgrade instead
helm upgrade sre-demo-app charts/sre-demo-app

# Verify release status
helm list
```

To override values without editing `values.yaml`:

```bash
# Example: deploy with a specific image tag and 3 replicas
helm upgrade sre-demo-app charts/sre-demo-app \
  --set image.tag=v1 \
  --set replicaCount=3
```

---

## Step 2B — Deploy via Plain Manifest (alternative)

```bash
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml
```

> Note: the plain manifest version does not include liveness/readiness probes, resource limits, or HPA. Use the Helm chart for production-grade deployments.

---

## Step 3 — Verify Deployment

```bash
# Check pods are Running
kubectl get pods

# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# sre-demo-app-xxxx-xxxx          1/1     Running   0          2m
# sre-demo-app-xxxx-yyyy          1/1     Running   0          2m

# Check service and get NLB external endpoint
kubectl get svc sre-demo-app

# Expected output (EXTERNAL-IP will be an AWS NLB DNS name):
# NAME          TYPE           CLUSTER-IP     EXTERNAL-IP                     PORT(S)        AGE
# sre-demo-app   LoadBalancer   10.100.x.x     xxxx.elb.ap-southeast-1...      80:3xxxx/TCP   3m

# Wait for NLB to be provisioned (usually 1-3 minutes)
# Then test the endpoint
NLB_DNS=$(kubectl get svc sre-demo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$NLB_DNS/sre.txt

# Expected output:
# Hello SRE!
```

---

## Step 4 — Verify HPA is Active

```bash
kubectl get hpa

# Expected output:
# NAME          REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS
# sre-demo-app   Deployment/sre-demo-app   2%/80%    2         5         2
```

> HPA requires the Kubernetes Metrics Server to be running. On EKS, install it with:
> `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`

---

## Additional Architecture Highlights

### Resource Limits (values.yaml)
Every container has `requests` and `limits` defined. This ensures:
- The K8s scheduler places pods on nodes with sufficient capacity (`requests`)
- No single pod can starve other workloads by consuming unbounded CPU/memory (`limits`)

### Liveness vs Readiness Probe
| Probe | Path | Failure action |
|---|---|---|
| Liveness | `/` | Restart the container |
| Readiness | `/sre.txt` | Remove pod from Service endpoints (stop sending traffic) |

The readiness probe targets `/sre.txt` specifically — if the core content becomes unavailable, traffic stops being routed to that pod immediately.

### HPA — Horizontal Pod Autoscaler
Configured in `values.yaml` with `autoscaling.enabled: true`. Scales between 2 and 5 replicas based on CPU utilization. The minimum of 2 replicas ensures availability even during a node failure in one AZ.

### NLB vs CLB
The Helm `service.yaml` uses the `aws-load-balancer-type: nlb` annotation to request a Network Load Balancer, which is preferred over the legacy Classic Load Balancer for lower latency and better AWS integration.

---

## Cleanup

```bash
# Uninstall Helm release (removes deployment + service + NLB)
helm uninstall sre-demo-app

# Or if deployed via manifest
kubectl delete -f kubernetes/
```
