variable "aws_region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS 部署的目標區域"
}

variable "cluster_name" {
  type        = string
  default     = "sre-demo-cluster"
  description = "EKS 叢集的專屬名稱"
}

variable "vpc_cidr" {
  type        = string
  default     = "172.31.0.0/16"
  description = "VPC 的主要網路範圍"
}
