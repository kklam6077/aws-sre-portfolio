# SRE-Pretest, candidate Lam Kin Kwan

# SRE Pretest — AWS Infrastructure (Terraform)

This project provisions a production-style AWS environment using Terraform, including a VPC with public/private subnets, and an EKS cluster with managed node groups. Remote state is stored in S3.

---

## Architecture Overview

```
Internet
    └── Internet Gateway
            └── Public Subnet (× 3 AZs)
                    ├── NAT Gateway          ← private subnet outbound traffic
                    └── External ELB         ← ingress from internet (provisioned by EKS)
                            └── Private Subnet (× 3 AZs)
                                    └── EKS Worker Nodes (Managed Node Group)
                                            └── Pods / Services
```

### Subnet Design

| Type | CIDR Example | Purpose |
|---|---|---|
| Public | 10.0.101.0/24 ~ 10.0.103.0/24 | ELB, NAT Gateway |
| Private | 10.0.1.0/24 ~ 10.0.3.0/24 | EKS Worker Nodes |

All subnets are spread across **3 Availability Zones** for high availability.

---

## File Structure

```
terraform/
├── provider.tf   # Terraform version, AWS provider, S3 backend (partial config)
├── main.tf       # S3 remote state bucket + versioning, local variable aliases
├── vpc.tf        # VPC module — subnets, NAT Gateway, subnet tags for EKS
└── eks.tf        # EKS module — cluster, managed node group
```

---

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate IAM permissions
- An existing S3 bucket for remote state (see `main.tf`)

---

## Remote State (Partial Configuration)

This project uses **Partial Configuration** for the S3 backend. The `backend "s3" {}` block in `provider.tf` is intentionally left empty, so sensitive values are injected at `terraform init` time rather than hard-coded.

```bash
terraform init \
  -backend-config="bucket=sre-demo-sre-tfstate-<YOUR_AWS_ACCOUNT_ID>" \
  -backend-config="key=sre-pretest/terraform.tfstate" \
  -backend-config="region=ap-northeast-1"
```

This pattern allows the same Terraform code to be reused across multiple environments (dev / staging / prod) by switching the backend config, without modifying any `.tf` files.

---

## Usage

### 1. Initialize

```bash
terraform init \
  -backend-config="bucket=sre-demo-sre-tfstate-<YOUR_AWS_ACCOUNT_ID>" \
  -backend-config="key=sre-pretest/terraform.tfstate" \
  -backend-config="region=ap-northeast-1"
```

### 2. Plan

```bash
terraform plan -var-file=terraform.tfvars
```

### 3. Apply

```bash
terraform apply -var-file=terraform.tfvars
```

### 4. Configure kubectl

After the cluster is created, update your local kubeconfig:

```bash
aws eks update-kubeconfig \
  --region <aws_region> \
  --name <cluster_name>
```

---

## Variables

| Variable | Description | Example |
|---|---|---|
| `aws_region` | AWS region to deploy into | `ap-northeast-1` |
| `cluster_name` | EKS cluster name | `sre-demo-cluster` |
| `vpc_cidr` | CIDR block for the VPC | `10.0.0.0/16` |

Define these in a `terraform.tfvars` file (not committed to version control):

```hcl
aws_region   = "ap-northeast-1"
cluster_name = "sre-demo-cluster"
vpc_cidr     = "10.0.0.0/16"
```

---

## Key Design Decisions

### Single NAT Gateway
`single_nat_gateway = true` is used to reduce cost in this pretest environment. All three private subnets share one NAT Gateway. In a production environment, one NAT Gateway per AZ is recommended to avoid a single point of failure.

### EKS Endpoint Public Access
`cluster_endpoint_public_access = true` allows the Kubernetes API server to be reached from outside the VPC, which is required for `kubectl` and CI/CD pipelines. In production, restrict access using `cluster_endpoint_public_access_cidrs`.

### Subnet Tags for EKS Load Balancer Discovery
EKS requires specific tags to automatically discover which subnets to place load balancers in:

```hcl
# Public subnets → External Load Balancer (internet-facing)
"kubernetes.io/role/elb" = "1"

# Private subnets → Internal Load Balancer (intra-VPC)
"kubernetes.io/role/internal-elb" = "1"
```

Without these tags, EKS cannot auto-provision load balancers via Kubernetes `Service` or `Ingress` resources.

### S3 State Bucket — prevent_destroy
The S3 bucket has `prevent_destroy = true` in its lifecycle block. This prevents `terraform destroy` from accidentally deleting the remote state, which would cause all tracked resources to become unmanaged.

---

## Node Group Spec

| Setting | Value | Notes |
|---|---|---|
| Instance type | `t3.small` | 2 vCPU / 2 GB RAM — suitable for pretest |
| Capacity type | `ON_DEMAND` | Stable; switch to `SPOT` to reduce cost |
| Desired nodes | 2 | Initial count |
| Min nodes | 1 | Cluster Autoscaler lower bound |
| Max nodes | 3 | Cluster Autoscaler upper bound |
| Kubernetes version | 1.30 | Pinned for stability |

---

## State Management

Remote state is stored in S3 with versioning enabled. If the state becomes corrupted or is accidentally overwritten, previous versions can be restored directly from the S3 console or via the AWS CLI:

```bash
# List available state versions
aws s3api list-object-versions \
  --bucket sre-demo-sre-tfstate-<YOUR_AWS_ACCOUNT_ID> \
  --prefix sre-pretest/terraform.tfstate
```

---

## Notes

- IAM credentials are **not** configured in `provider.tf`. Supply them via environment variables (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) or an IAM Role (EC2 Instance Profile / OIDC for CI/CD).
- The `terraform.tfstate` file is managed remotely in S3 and should never be edited manually.
