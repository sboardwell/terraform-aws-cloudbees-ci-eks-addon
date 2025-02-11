# CloudBees CI blueprint add-on: At scale with Karpeter

## Reference

- [Karpenter Blueprints for Amazon EKS](https://github.com/aws-samples/karpenter-blueprints/tree/main)

<!-- BEGIN_TF_DOCS -->
### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| hosted_zone | Amazon Route 53 hosted zone. CloudBees CI applications are configured to use subdomains in this hosted zone. | `string` | n/a | yes |
| trial_license | CloudBees CI trial license details for evaluation. | `map(string)` | n/a | yes |
| aws_region | AWS region to deploy resources to. It requires at minimun 2 AZs. | `string` | `"us-west-2"` | no |
| ci | Running in a CI service versus running locally. False when running locally, true when running in a CI service. | `bool` | `false` | no |
| suffix | Unique suffix to assign to all resources. | `string` | `""` | no |
| tags | Tags to apply to resources. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|------|-------------|
| eks_cluster_name | Cluster name of the EKS cluster |
| kubeconfig_add | Adds kubeconfig to the local configuration to access the Kubernetes API. |
| kubeconfig_export | Exports the KUBECONFIG environment variable to access the Kubernetes API. |
| node_instance_role_name | IAM Role name that each Karpenter node will use |
| vpc_id | VPC ID that the EKS cluster is using |
<!-- END_TF_DOCS -->
