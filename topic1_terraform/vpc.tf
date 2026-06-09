# ========================================================
# 直接用 Terraform Registry 的官方Module, 避免手寫錯誤
# ========================================================


module "vpc" {

  source  = "terraform-aws-modules/vpc/aws"

  version = "~> 5.0"



  name = "sre-demo-sre-vpc"

  cidr = local.vpc_cidr 


# ============================================================
# 在main.tf 中, local 中先定好的region 和 vpc_cidr
# cidrsubnet 的方式切出Subnet, 更改var 中的內容, 提高可重用性
# ============================================================
 
  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]

  private_subnets = [
	cidrsubnet(local.vpc_cidr, 8, 1), 
	cidrsubnet(local.vpc_cidr, 8, 2), 
	cidrsubnet(local.vpc_cidr, 8, 3)
  ]

  public_subnets  = [
	cidrsubnet(local.vpc_cidr, 8, 101), 
	cidrsubnet(local.vpc_cidr, 8, 102), 
	cidrsubnet(local.vpc_cidr, 8, 103)
  ]

# =========================================================
# 建立一個NAT GW, 令subnet 可主動對外連線
# 可改用 VPC Endpoint
# ========================================================

  enable_nat_gateway = true

  single_nat_gateway = true


# ========================================================
# 加上 Tag 以建立Load Balancer
# ========================================================
  public_subnet_tags = {

    "kubernetes.io/role/elb" = "1"

  }

  private_subnet_tags = {

    "kubernetes.io/role/internal-elb" = "1"

  }

}
