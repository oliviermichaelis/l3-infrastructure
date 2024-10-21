module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.26.0"

  cluster_name = module.eks.cluster_name

  enable_pod_identity    = false
  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # The following is used as a prefix
  iam_role_name            = "KarpenterController-${module.eks.cluster_name}"
  iam_role_use_name_prefix = true # default

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

# The data is only available in one region
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us_east_1
}

resource "helm_release" "karpenter-crd" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter-crd"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter-crd"
  version             = "1.0.5"
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true
  skip_crds        = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.0.5"

  values = [
    <<-EOT
    replicas: 1
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueueName: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    controller:
      resources:
        requests:
          cpu: 250m
          memory: 450Mi # this needs to be below 512Mi, otherwise an even bigger Fargate instance is chosen
        limits:
          memory: 450Mi
    settings:
      clusterName: ${module.eks.cluster_name}
      featureGates:
        spotToSpotConsolidation: true
    # This is a dummy variable to create an indirect dependency to the fargate profile for karpenter
    karpenterDependency: ${module.eks.fargate_profiles.karpenter.fargate_profile_status}
    EOT
  ]

  lifecycle {
    ignore_changes = [
      # The repository_password is dynamically fetched via the aws_ecrpublic_authorization_token data source.
      # However, we cannot ignore the change, as otherwise a stale authorization token would be used
      #repository_password,
    ]
  }

  depends_on = [
    helm_release.karpenter-crd
  ]
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      amiSelectorTerms:
        - alias: al2@latest
      metadataOptions:
        httpPutResponseHopLimit: 2
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool_spot" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: spot
    spec:
      template:
        metadata:
          annotations:
            node.kubernetes.io/lifecycle: spot
        spec:
          nodeClassRef:
            kind: EC2NodeClass
            group: karpenter.k8s.aws
            name: default
          requirements:
            - key: "topology.kubernetes.io/zone"
              operator: In
              values: ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["2", "4", "8"]
            - key: "karpenter.k8s.aws/instance-size"
              operator: NotIn
              values: ["nano", "micro"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["3"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: "kubernetes.io/os"
              operator: In
              values: ["linux"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["spot"]
      limits:
        cpu: "12"
        memory: 64Gi
      disruption:
        consolidationPolicy: WhenEmptyOrUnderutilized
        consolidateAfter: 2m
        expireAfter: 24h
      weight: 20
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

