data "aws_route53_zone" "this" {
  name = var.hosted_zone
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr
}

data "aws_availability_zones" "available" {
  # Do not include local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name                 = var.suffix == "" ? "cbci-bp03" : "cbci-bp03-${var.suffix}"
  vpc_name             = "${local.name}-vpc"
  cluster_name         = "${local.name}-eks"
  resource_group_name  = "${local.name}-rg"
  kubeconfig_file      = "kubeconfig_${local.name}.yaml"
  kubeconfig_file_path = abspath("k8s/${local.kubeconfig_file}")

  vpc_cidr         = "10.0.0.0/16"
  route53_zone_id  = data.aws_route53_zone.this.id
  route53_zone_arn = data.aws_route53_zone.this.arn
  azs              = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge(var.tags, {
    "tf-blueprint"  = local.name
    "tf-repository" = "github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon"
  })

}

################################################################################
# EKS: Add-ons
################################################################################

# CloudBees CI Add-on

module "eks_blueprints_addon_cbci" {
  #source  = "cloudbees/cloudbees-ci-eks-addon/aws"
  #version = ">= 3.18306.0"
  source = "../../"

  depends_on = [module.eks_blueprints_addons]

  hosted_zone   = var.hosted_zone
  cert_arn      = module.acm.acm_certificate_arn
  trial_license = var.trial_license

}

# EKS Blueprints Add-ons

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.29.0"

  role_name_prefix = "${module.eks.cluster_name}-ebs-csi-driv"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  #vEKSBpAddonsTFMod#
  version = "1.19.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  oidc_provider_arn = module.eks.oidc_provider_arn
  cluster_version   = module.eks.cluster_version

  eks_addons = {
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
      # ensure any PVC created also includes the custom tags
      configuration_values = jsonencode(
        {
          controller = {
            extraVolumeTags = local.tags
          }
        }
      )
    }
    coredns    = {}
    vpc-cni    = {}
    kube-proxy = {}
  }

  enable_external_dns = true
  external_dns = {
    values = [templatefile("k8s/extdns-values.yml", {
      zoneDNS = var.hosted_zone
    })]
  }
  external_dns_route53_zone_arns      = [local.route53_zone_arn]
  enable_aws_load_balancer_controller = true

  tags = local.tags
}

################################################################################
# EKS: Infra
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = local.name
  cluster_version = "1.30"

  # Give the Terraform identity admin access to the cluster
  # which will allow it to deploy resources into the cluster
  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    coredns = {
      configuration_values = jsonencode({
        tolerations = [
          # Allow CoreDNS to run on the same nodes as the Karpenter controller
          # for use during cluster creation when Karpenter nodes do not yet exist
          {
            key    = "karpenter.sh/controller"
            value  = "true"
            effect = "NoSchedule"
          }
        ]
      })
    }
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    karpenter = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["m5.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = {
        # Used to ensure Karpenter runs on nodes that it does not manage
        "karpenter.sh/controller" = "true"
      }

      taints = {
        # The pods that do not tolerate this taint should run on nodes
        # created by Karpenter
        karpenter = {
          key    = "karpenter.sh/controller"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  node_security_group_tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  })

  tags = local.tags
}

# Storage Classes

resource "kubernetes_annotations" "gp2" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  # This is true because the resources was already created by the ebs-csi-driver addon
  force = "true"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    encrypted = "true"
    fsType    = "ext4"
    type      = "gp3"
  }

}

# Kubeconfig
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

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  # Important: Application Services Hostname must be the same as the domain name or subject_alternative_names
  domain_name = var.hosted_zone
  subject_alternative_names = [
    "*.${var.hosted_zone}" # For subdomains example.${var.domain_name}
  ]

  # https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
  zone_id           = local.route53_zone_id
  validation_method = "DNS"

  tags = local.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.2"

  name = local.vpc_name
  cidr = local.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  # https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html
  # https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.name
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags

}

resource "aws_resourcegroups_group" "bp_rg" {
  name = local.resource_group_name

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "tf-blueprint",
      "Values": ["${local.name}"]
    }
  ]
}
JSON
  }
}
