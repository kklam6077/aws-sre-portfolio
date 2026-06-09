# Topic 6 — Linking Terraform Resources to Helm Chart


## Existing outputs.tf

Current project already defines the following outputs in `topic1_terraform/outputs.tf`:

```hcl
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}
output "private_subnets" {
  value       = module.vpc.private_subnets
  description = "Private Subnet ID"
}
output "public_subnets" {
  value       = module.vpc.public_subnets
  description = "Public Subnet ID"
}
output "eks_cluster_name" {
  value       = local.cluster_name
  description = "EKS Cluster name"
}
```

So when a service needs to reference a Terraform-managed resource (such as a WAF ACL or RDS endpoint), the following approach can be used.

---

## Solution: Terraform Output + CI/CD Injection

### Step 1: Add the Required Output to outputs.tf

Using WAF ACL as an example, expose the ARN after Terraform creates the resource:

```hcl
# Add to topic1_terraform/outputs.tf
output "waf_acl_arn" {
  description = "WAF ACL 的 ARN"
  value       = aws_wafv2_web_acl.main.arn
}
```

### Step 2: Read the Output in the CI/CD Pipeline

After `terraform apply` completes, the pipeline reads the output value and passes it to `helm upgrade` using `--set`:

```yaml
# In deploy.yaml, after terraform apply

- name: Read Terraform outputs
  working-directory: ${{ env.TF_WORKING_DIR }}
  run: |
    # Read existing outputs
    EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
    VPC_ID=$(terraform output -raw vpc_id)
    # Read the new WAF output
    WAF_ACL_ARN=$(terraform output -raw waf_acl_arn)
    # Store as environment variables
    echo "EKS_CLUSTER=$EKS_CLUSTER" >> $GITHUB_ENV
    echo "VPC_ID=$VPC_ID" >> $GITHUB_ENV
    echo "WAF_ACL_ARN=$WAF_ACL_ARN" >> $GITHUB_ENV

- name: Deploy to EKS via Helm
  run: |
    helm upgrade --install ${{ env.HELM_RELEASE_NAME }} \
      ./topic3_helm_kubernetes/sre-demo-app \
      -f topic3_helm_kubernetes/sre-demo-app/values.yaml \
      -f topic3_helm_kubernetes/sre-demo-app/${{ env.HELM_VALUES }} \
      --set image.repository=$ECR_REGISTRY/$ECR_REPOSITORY \
      --set image.tag=$IMAGE_TAG \
      --set annotations.wafAclArn=${{ env.WAF_ACL_ARN }}
```

### Step 3: Reference the Value in the Helm Chart

The value is kept empty in `values.yaml` and injected at deploy time via `--set` :

```yaml
# topic3_helm_kubernetes/sre-demo-app/values.yaml
annotations:
  wafAclArn: ""   # injected by CI/CD pipeline at deploy time
```

```yaml
# topic3_helm_kubernetes/sre-demo-app/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "sre-demo-app.fullname" . }}
  annotations:
    {{- if .Values.annotations.wafAclArn }}
    # WAF ACL ARN injected from Terraform output via CI/CD pipeline
    service.beta.kubernetes.io/aws-waf-acl-arn: {{ .Values.annotations.wafAclArn }}
    {{- end }}
```
---

## Flow Summary

```
Terraform apply
    └── creates AWS resource (e.g. WAF ACL)
            └── outputs.tf exposes the ARN
                    └── CI/CD reads it with terraform output -raw
                            └── helm upgrade --set injects it
                                    └── Helm chart uses it as annotation
```
