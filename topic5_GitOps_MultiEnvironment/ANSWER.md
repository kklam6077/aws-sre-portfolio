# Topic 5 — GitOps 多環境部署

## 什麼是 GitOps？

GitOps 是一種以 Git 作為**唯一真實來源（Single Source of Truth）**的實踐方式，所有對系統的變更都必須透過 Git commit 和 Pull Request 進行，這帶來三個核心好處：

- **可審計（Auditable）**：所有變更都有記錄，清楚知道誰在什麼時間改了什麼
- **可回滾（Reversible）**：revert 一個 commit 就等於回滾一次部署
- **Pipeline 是唯一部署途徑**：禁止直接在 cluster 上手動執行 `kubectl apply` 或 `helm upgrade`，所有部署都必須經過 Git

---

## Branch 策略

每個 branch 對應一個特定環境，merge PR 進某個 branch 是觸發該環境部署的唯一方式。

```
feature/*
    └── PR → develop    → 部署到 alpha 環境
                └── PR → staging   → 部署到 staging 環境
                              └── PR → main      → 部署到 production 環境
```

這形成了一個**單向晉升流程（Promotion Flow）**，程式碼必須依序通過 alpha 和 staging 的測試，才能進入 production，確保每個階段都有驗證。

---

## 相同 Codebase，不同 Values

Helm chart（`topic3_helm_kubernetes/sre-demo-app`）在所有環境共用同一份，環境之間的差異只在於部署時使用的 values 檔案。

```
topic3_helm_kubernetes/sre-demo-app/
├── values.yaml               # 所有環境共用的基礎預設值
├── values.alpha.yaml         # Alpha 環境的覆蓋設定
├── values.staging.yaml       # Staging 環境的覆蓋設定
└── values.production.yaml    # Production 環境的覆蓋設定
```

### 範例：values.alpha.yaml
```yaml
# Alpha：最小資源配置，不啟用 HPA，只做基本功能驗證
replicaCount: 1

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

autoscaling:
  enabled: false
```

### 範例：values.production.yaml
```yaml
# Production：較高副本數、啟用 HPA、更多資源配置
replicaCount: 3

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 200m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

Helm 透過 `-f` 將基礎 values 和環境專屬 values 合併：

```bash
helm upgrade --install sre-demo-web-production ./topic3_helm_kubernetes/sre-demo-app \
  -f topic3_helm_kubernetes/sre-demo-app/values.yaml \
  -f topic3_helm_kubernetes/sre-demo-app/values.production.yaml \
  --set image.tag=$IMAGE_TAG
```

後面的 `-f` 會覆蓋前面的同名參數，確保環境設定優先生效，同時保留 base 的預設值。

---

## Pipeline 多環境邏輯

Pipeline 透過讀取 `github.base_ref`（PR 的目標 branch）來判斷要部署到哪個環境：

```yaml
- name: Set environment variables
  run: |
    if [[ "${{ github.base_ref }}" == "main" ]]; then
      echo "ENV=production" >> $GITHUB_ENV
      echo "EKS_CLUSTER_NAME=sre-demo-cluster-prod" >> $GITHUB_ENV
      echo "HELM_VALUES=values.production.yaml" >> $GITHUB_ENV
    elif [[ "${{ github.base_ref }}" == "staging" ]]; then
      echo "ENV=staging" >> $GITHUB_ENV
      echo "EKS_CLUSTER_NAME=sre-demo-cluster-staging" >> $GITHUB_ENV
      echo "HELM_VALUES=values.staging.yaml" >> $GITHUB_ENV
    else
      echo "ENV=alpha" >> $GITHUB_ENV
      echo "EKS_CLUSTER_NAME=sre-demo-cluster-alpha" >> $GITHUB_ENV
      echo "HELM_VALUES=values.alpha.yaml" >> $GITHUB_ENV
    fi
```

每個環境還有各自獨立的：
- **EKS cluster**：環境之間完全隔離
- **Helm release name**：`sre-demo-web-alpha`、`sre-demo-web-production`

---

## Production 人工審核

Production 部署在執行 Helm deploy 之前，需要額外的人工審核步驟。透過 GitHub Environments 的 required reviewers 功能實現：

```yaml
deploy-production:
  needs: build
  environment:
    name: production    # 在 GitHub repo Settings → Environments 設定
                        # 並指定 required reviewers
  steps:
    - name: Deploy to production
      run: |
        helm upgrade --install sre-demo-web-production ...
```

當 pipeline 執行到這個 job 時，GitHub 會暫停並通知指定的 reviewer。只有 reviewer 在 GitHub UI 點擊核准後，部署才會繼續執行。這確保了 production 的任何變更都有人工把關。

---

## 總結

| 環境 | 觸發條件 | EKS Cluster | 審核方式 |
|---|---|---|---|
| Alpha | PR merge → develop | sre-demo-cluster-alpha | 自動部署 |
| Staging | PR merge → staging | sre-demo-cluster-staging | 自動部署 |
| Production | PR merge → main | sre-demo-cluster-prod | 需要人工審核 |

