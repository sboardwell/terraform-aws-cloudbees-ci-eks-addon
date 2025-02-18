# CloudBees CI blueprint add-on: At scale with Karpeter

## Terraform documentation

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

## Prerequisites

This blueprint uses [DockerHub](https://hub.docker.com/) as a container registry service. Note that an existing DockerHub account is required (username, password, and email).

> [!TIP]
> Use `docker login` to validate username and password.

## Deploy

When preparing to deploy, you must complete the following steps:

1. Customize your Terraform values by copying `.auto.tfvars.example` to `.auto.tfvars`.
1. Initialize the root module and any associated configuration for providers.
1. Create the resources and deploy CloudBees CI to an EKS cluster. Refer to [Amazon EKS Blueprints for Terraform - Deploy](https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy).

For more information, refer to [The Core Terraform Workflow](https://www.terraform.io/intro/core-workflow) documentation.

> [!TIP]
> The `deploy` phase can be orchestrated via the companion [Makefile](../Makefile).

## Validate

Once the blueprint has been deployed, you can validate it.

### Kubeconfig

Once the resources have been created, a `kubeconfig` file is created in the [/k8s](k8s) folder. Issue the following command to define the [KUBECONFIG](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#the-kubeconfig-environment-variable) environment variable to point to the newly generated file:

    ```sh
    eval $(terraform output --raw kubeconfig_export)
    ```

If the command is successful, no output is returned.

### Examples

    ```sh
    kubectl apply -f examples/statefulset.yaml
    kubectl scale deployment.apps/stateful --replicas=10
    kubectl delete -f examples/statefulset.yaml
    ```

## Reference

- [Karpenter Blueprints for Amazon EKS](https://github.com/aws-samples/karpenter-blueprints/tree/main)