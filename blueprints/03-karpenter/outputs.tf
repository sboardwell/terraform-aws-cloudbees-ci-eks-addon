output "eks_cluster_name" {
  description = "Cluster name of the EKS cluster"
  value       = module.eks.cluster_name
}
output "vpc_id" {
  description = "VPC ID that the EKS cluster is using"
  value       = module.vpc.vpc_id
}

output "node_instance_role_name" {
  description = "IAM Role name that each Karpenter node will use"
  value       = module.eks_blueprints_addons.karpenter.node_iam_role_name
}

output "kubeconfig_export" {
  description = "Exports the KUBECONFIG environment variable to access the Kubernetes API."
  value       = "export KUBECONFIG=${local.kubeconfig_file_path}"
}

output "kubeconfig_add" {
  description = "Adds kubeconfig to the local configuration to access the Kubernetes API."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}