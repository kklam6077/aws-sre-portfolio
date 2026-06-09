# ===================================================================
# locals 區隔 : 把var 改local, 方便模組統一引用
# ===================================================================

locals {
  cluster_name = var.cluster_name
  region       = var.aws_region
  vpc_cidr     = var.vpc_cidr
}

# ================================================================================
# 用S3 Bucket 來存放 Terraform Remote State 檔案 避免存放Serive ID等重要數據在本地
# 加上 Prevent Destroy 來避免terraform destory Delete Bucket
# ================================================================================

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "sre-demo-sre-tfstate-<YOUR_AWS_ACCOUNT_ID>"
  
  lifecycle {
    prevent_destroy = true
  }
}

# =================================================================
# 加上S3 Verion Control, 確保tfstate 可以回滾至前一版本
# =================================================================

resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
