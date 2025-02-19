data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_route53_zone" "this" {
  name = var.hosted_zone
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {

  name            = var.suffix == "" ? "cbci-bp03" : "cbci-bp03-${var.suffix}"
  cluster_version = "1.30"
  region          = var.aws_region

  node_iam_role_name = module.eks_blueprints_addons.karpenter.node_iam_role_name

  route53_zone_arn = data.aws_route53_zone.this.arn
  route53_zone_id  = data.aws_route53_zone.this.id

  vpc_cidr = "10.0.0.0/16"
  # NOTE: You might need to change this less number of AZs depending on the region you're deploying to
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge(var.tags, {
    "tf-blueprint"  = local.name
    "tf-repository" = "github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon"
  })

  kubeconfig_file      = "kubeconfig_${local.name}.yaml"
  kubeconfig_file_path = abspath("k8s/${local.kubeconfig_file}")

}

################################################################################
# EKS: Add-ons
################################################################################

module "eks_blueprints_addon_cbci" {
  #source  = "cloudbees/cloudbees-ci-eks-addon/aws"
  #version = ">= 3.18306.0"
  source = "../../"

  depends_on = [module.eks_blueprints_addons]

  hosted_zone   = var.hosted_zone
  cert_arn      = module.acm.acm_certificate_arn
  trial_license = var.trial_license

}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.3"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_delay_dependencies = [for prof in module.eks.eks_managed_node_groups : prof.node_group_arn]

  eks_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
  }
  #####################
  #01-getting-started
  #####################
  enable_external_dns = true
  external_dns = {
    values = [templatefile("k8s/extdns-values.yml", {
      zoneDNS = var.hosted_zone
    })]
  }
  external_dns_route53_zone_arns      = [local.route53_zone_arn]
  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    values = [file("k8s/aws-alb-controller-values.yml")]
  }
  #####################
  #03-karpenter
  #####################
  enable_metrics_server    = true
  enable_aws_for_fluentbit = true
  aws_for_fluentbit = {
    set = [
      {
        name  = "cloudWatchLogs.region"
        value = local.region
      }
    ]
  }

  enable_karpenter = true

  karpenter = {
    chart_version       = "1.0.1"
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }
  karpenter_enable_spot_termination          = true
  karpenter_enable_instance_profile_creation = true
  karpenter_node = {
    iam_role_use_name_prefix = false
  }

  tags = local.tags
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  role_name_prefix = "${module.eks.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

module "aws_auth" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
  ]
}

################################################################################
# EKS: Infra
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.23.0"

  cluster_name                   = local.name
  cluster_version                = local.cluster_version
  cluster_endpoint_public_access = true

  cluster_addons = {
    kube-proxy = { most_recent = true }
    coredns    = { most_recent = true }

    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  create_cloudwatch_log_group              = false
  create_cluster_security_group            = false
  create_node_security_group               = false
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    mg_5 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m4.large", "m5.large", "m5a.large", "m5ad.large", "m5d.large", "t2.large", "t3.large", "t3a.large"]

      create_security_group = false

      subnet_ids   = module.vpc.private_subnets
      max_size     = 2
      desired_size = 2
      min_size     = 2

      # Launch template configuration
      create_launch_template = true              # false will use the default launch template
      launch_template_os     = "amazonlinux2eks" # amazonlinux2eks or bottlerocket

      labels = {
        intent = "control-apps"
      }
    }
  }

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })
}

# Storage Classes

resource "kubernetes_annotations" "gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  # This is true because the resources was already created by the ebs-csi-driver addon
  force      = "true"
  depends_on = [module.eks]

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}

resource "kubernetes_storage_class_v1" "gp3_a" {
  metadata {
    name = "gp3-a"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  depends_on = [module.eks]

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  # Issue #195
  allowed_topologies {
    match_label_expressions {
      key    = "topology.ebs.csi.aws.com/zone"
      values = ["${var.aws_region}a"]
    }
  }

  parameters = {
    encrypted = "true"
    fsType    = "ext4"
    type      = "gp3"
  }

}

# Kubecofig

resource "terraform_data" "create_kubeconfig" {
  depends_on = [module.eks]

  triggers_replace = var.ci ? [timestamp()] : []

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --kubeconfig ${local.kubeconfig_file_path}"
  }
}

################################################################################
# Supported Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.12.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets = ["10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${local.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${local.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${local.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
    "karpenter.sh/discovery"              = local.name
  }

  tags = var.tags
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  #Important: Application Services Hostname must be the same as the domain name or subject_alternative_names
  domain_name = var.hosted_zone
  subject_alternative_names = [
    "*.${var.hosted_zone}" # For subdomains example.${var.domain_name}
  ]

  #https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
  zone_id           = local.route53_zone_id
  validation_method = "DNS"

  tags = local.tags
}
