terraform {
  required_version = ">= 1.0.0"

   # 用terraform 建議的 Partial Configuration, bucket/key/region 可用CLI/ CICD 傳入
   # 提高可重用性 
   backend "s3" {}

   # 初始化指令範例：
   # terraform init \
   #   -backend-config="bucket=sre-demo-sre-tfstate-<YOUR_AWS_ACCOUNT_ID>" \
   #   -backend-config="key=sre-pretest/terraform.tfstate" \
   #   -backend-config="region=ap-northeast-1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
