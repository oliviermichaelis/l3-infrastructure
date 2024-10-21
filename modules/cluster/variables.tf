variable "cluster_name" {
  type        = string
  description = "Name for the cluster"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block of the VPC in question"
}
