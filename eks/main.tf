terraform {
  required_version = "1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.82.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.31.0"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.default.token
  }
}

module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.31.1"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_ipv4_irsa_role.iam_role_arn
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
    aws-mountpoint-s3-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.s3_csi_irsa_role.iam_role_arn
      configuration_values     = "{\"node\":{\"tolerateAllTaints\":true}}"
    }
    snapshot-controller = {
      most_recent = true
    }
  }
  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnets
  control_plane_subnet_ids = var.intra_subnets

  cluster_endpoint_public_access = true

  node_security_group_additional_rules = {
    istio_sidecar_injection = {
      description                   = "Istio Sidecar Injection"
      protocol                      = "tcp"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  eks_managed_node_group_defaults = {
    ami_type        = "AL2023_x86_64_STANDARD"
    instance_types  = ["m7i-flex.xlarge"]
    disk_size       = 20
    create_iam_role = false
    iam_role_arn    = module.node_groups_iam_role.iam_role_arn
  }
  eks_managed_node_groups = var.eks_managed_node_groups

  enable_irsa = true

  cluster_enabled_log_types = []
  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }
}

module "node_groups_iam_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "5.48.0"

  create_role       = true
  role_name         = "${var.cluster_name}-node-group"
  role_requires_mfa = false

  trusted_role_actions  = ["sts:AssumeRole"]
  trusted_role_services = ["ec2.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
  number_of_custom_role_policy_arns = 2
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks_cluster.cluster_name
}

module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true
  oidc_providers = {
    ex = {
      provider_arn               = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "s3_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"

  role_name = "${var.cluster_name}-s3-csi"
  oidc_providers = {
    ex = {
      provider_arn               = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:s3-csi-driver-sa"]
    }
  }
}

module "vpc_cni_ipv4_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"

  role_name             = "${var.cluster_name}-vpc-cni-ipv4"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"
  count   = var.in_cluster_setting ? 1 : 0

  role_name                              = "${var.cluster_name}-load-balancer-controller"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    ex = {
      provider_arn               = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"
  count   = var.in_cluster_setting ? 1 : 0

  role_name                     = "${var.cluster_name}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = var.dns_hosted_zone_arns
  oidc_providers = {
    ex = {
      provider_arn               = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

module "log_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"
  count   = var.in_cluster_setting ? 1 : 0

  bucket_prefix = "${var.cluster_name}-loki-"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  force_destroy            = false
}

module "loki_iam_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.1"
  count   = var.in_cluster_setting ? 1 : 0

  name = "${var.cluster_name}-loki"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${module.log_bucket[0].s3_bucket_arn}",
          "${module.log_bucket[0].s3_bucket_arn}/*"
        ]
      }
    ]
  })
  depends_on = [module.log_bucket]
}

module "loki_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.48.0"
  count   = var.in_cluster_setting ? 1 : 0

  role_name = "${var.cluster_name}-loki"
  role_policy_arns = {
    policy = module.loki_iam_policy[0].arn
  }
  oidc_providers = {
    ex = {
      provider_arn               = module.eks_cluster.oidc_provider_arn
      namespace_service_accounts = ["observability:loki"]
    }
  }
  depends_on = [module.loki_iam_policy]
}

data "aws_iam_policy_document" "dlm_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "dlm_lifecycle_role" {
  name               = "${var.cluster_name}-dlm-lifecycle-role"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume_role.json
}

data "aws_iam_policy_document" "dlm_lifecycle" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSnapshot",
      "ec2:CreateSnapshots",
      "ec2:DeleteSnapshot",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
    ]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*::snapshot/*"]
  }
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  name   = "${var.cluster_name}-dlm-lifecycle-policy"
  role   = aws_iam_role.dlm_lifecycle_role.id
  policy = data.aws_iam_policy_document.dlm_lifecycle.json
}

resource "aws_dlm_lifecycle_policy" "snapshot" {
  description        = "snapshot"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"
  policy_details {
    resource_types = ["VOLUME"]
    schedule {
      name = "2 weeks of daily snapshots"
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["20:00"]
      }
      retain_rule {
        count = 14
      }
      copy_tags = false
    }
    target_tags = {
      Snapshot = "true"
    }
  }
}

# TODO
# aws eks update-kubeconfig --region <region-code> --name <my-cluster>
# kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
# kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml
