module "eu-central-1" {
  source = "../modules/cluster"

  providers = {
    aws           = aws.eu-central-1
    aws.us_east_1 = aws.us-east-1
    kubernetes    = kubernetes.eu-central-1
    kubectl       = kubectl.eu-central-1
    helm          = kubectl.eu-central-1
  }

  cluster_name   = "cluster-1"
  vpc_cidr_block = "10.0.0.0/16"
}

module "eu-west-3" {
  source = "../modules/cluster"

  providers = {
    aws           = aws.eu-west-3
    aws.us_east_1 = aws.us-east-1
    kubernetes    = kubernetes.eu-west-3
    kubectl       = kubectl.eu-west-3
    helm          = kubectl.eu-west-3
  }

  cluster_name   = "cluster-1"
  vpc_cidr_block = "10.1.0.0/16"
}

#module "eu-south-1" {
#  source = "../modules/cluster"
#
#  providers = {
#    aws           = aws.eu-south-1
#    aws.us_east_1 = aws.us-east-1
#  }
#
#  cluster_name   = "cluster-1"
#  vpc_cidr_block = "10.2.0.0/16"
#}
