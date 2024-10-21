data "aws_availability_zones" "available" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.26.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  cluster_endpoint_public_access = true

  # See documentation: https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/docs/network_connectivity.md
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 65535
      type        = "ingress"
      self        = true
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  # Prevent additional cost of cloudwatch logs
  create_cloudwatch_log_group = false
  cluster_enabled_log_types   = []

  cluster_addons = {
    # Addons versions need to match cluster versions (eg. K8s=1.29)
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        computeType  = "Fargate"
        replicaCount = 1
        # Ensure that we fully utilize the minimum amount of resources that are supplied by
        # Fargate https://docs.aws.amazon.com/eks/latest/userguide/fargate-pod-configuration.html
        # Fargate adds 256 MB to each pod's memory reservation for the required Kubernetes
        # components (kubelet, kube-proxy, and containerd). Fargate rounds up to the following
        # compute configuration that most closely matches the sum of vCPU and memory requests in
        # order to ensure pods always have the resources that they need to run.
        resources = {
          limits = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
          requests = {
            cpu = "0.25"
            # We are targeting the smallest Task size of 512Mb, so we subtract 256Mb from the
            # request/limit to ensure we can fit within that task
            memory = "256M"
          }
        }
      })
    }
    kube-proxy = {
      most_recent = true
      configuration_values = jsonencode({
        resources = {
          requests = {
            memory = "64Mi"
          }
          limits = {
            memory = "64Mi"
          }
        }
      })
    }
    vpc-cni = {
      most_recent = true

      # Values can be taken from the AWS console or from here:
      # https://artifacthub.io/packages/helm/aws/aws-vpc-cni
      configuration_values = jsonencode({
        # default resources for all containers in the pod
        resources = {
          requests = {
            memory = "64Mi"
          }
          limits = {
            memory = "64Mi"
          }
        }
        nodeAgent = {
          resources = {
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
            limits = {
              memory = "32Mi"
            }
          }
        }
      })
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Fargate Profile(s)
  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
    coredns = {
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "eks.amazonaws.com/component" = "coredns"
          }
        },
      ]
    }
  }

  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  kms_key_enable_default_policy = true

  tags = local.tags
}

# Allow DNS traffic from nodes to the cluster primary security group.
# CoreDNS currently runs on Fargate, which is subjected to the cluster primary security group.
resource "aws_vpc_security_group_ingress_rule" "cluster_primary_dns_tcp" {
  description                  = "Allow TCP DNS traffic from the nodes to CoreDNS on Fargate"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 53
  ip_protocol                  = "tcp"
  to_port                      = 53
  security_group_id            = module.eks.cluster_primary_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "cluster_primary_dns_udp" {
  description                  = "Allow UDP DNS traffic from the nodes to CoreDNS on Fargate"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 53
  ip_protocol                  = "udp"
  to_port                      = 53
  security_group_id            = module.eks.cluster_primary_security_group_id
}

# This rule is required for metrics-server to be able to scrape kubelet metrics on Fargate
resource "aws_vpc_security_group_ingress_rule" "kubelet_api" {
  description                  = "Allow TCP traffic from nodes to kubelet on Fargate"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 10250
  ip_protocol                  = "tcp"
  to_port                      = 10250
  security_group_id            = module.eks.cluster_primary_security_group_id
}

# This rule is required for prometheus to be able to scrape coredns metrics on Fargate
# This is optional
resource "aws_vpc_security_group_ingress_rule" "coredns_metrics" {
  description                  = "Allow TCP traffic from nodes to coredns on Fargate"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 9153
  ip_protocol                  = "tcp"
  to_port                      = 9153
  security_group_id            = module.eks.cluster_primary_security_group_id
}

# This rule is required for prometheus to be able to scrape karpenter metrics on Fargate
# This is optional
resource "aws_vpc_security_group_ingress_rule" "karpenter_metrics" {
  description                  = "Allow TCP traffic from nodes to karpenter on Fargate"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 8080
  ip_protocol                  = "tcp"
  to_port                      = 8080
  security_group_id            = module.eks.cluster_primary_security_group_id
}

