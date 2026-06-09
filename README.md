# Sre-Demo SRE Pretest — KK Lam

This repository contains my submission for the Sre-Demo SRE Pretest, covering infrastructure provisioning, containerization, Kubernetes deployment, and CI/CD pipeline design.

---

## Repository Structure

```
sre-pretest/
├── topic1_terraform/               # Topic 1 — AWS Infrastructure (Terraform)
├── topic2_docker/                  # Topic 2 — Dockerized Nginx Service
├── topic3_helm_kubernetes/         # Topic 3 — Kubernetes Deployment (Helm)
├── topic4_cicd/                    # Topic 4 — CI/CD Pipeline (GitHub Actions)  
├── topic5_GitOps_MultiEnvironment/ # Topic 5 — GitOps Multi-Environment Strategy
├── topic6_TerraformLink/           # Topic 6 — Linking Terraform to Helm
├── .github/workflows/deploy.yaml  # GitHub Actions pipeline
└── AI_DISCLOSURE.md                # AI assistance disclosure
```

---

## Where to Start

| Order | Folder | Read First g
g---|---|---|
| 1 | `topic1_terraform/` | `README.md` |
| 2 | `topic2_docker/` | `Instruction.md` |
| 3 | `topic3_helm_kubernetes/sre-demo-app/` | `INSTRUCTIONS.md` |
| 4 | `topic4_cicd` | `deploy.yaml` |
| 5 | `topic5_GitOps_MultiEnvironment/` | `ANSWER.md` |
| 6 | `topic6_TerraformLink/` | `ANSWER.md` |

---
## Architecute Summary


**Key components:**
- VPC with public/private subnets across 3 AZs
- EKS cluster with managed node group and HPA
- Docker image hosted on ECR
- Helm chart with liveness/readiness probes and resource limits
- GitHub Actions pipeline triggered on PR merge to main
