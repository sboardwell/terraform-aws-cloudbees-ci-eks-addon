---
applyTo: '**'
---

When working with Terraform code in this repository:

## Terraform Standards
- Always include main.tf, variables.tf, outputs.tf, versions.tf in modules
- Use snake_case for resources, kebab-case for modules
- All variables and outputs MUST have descriptions
- Always tag resources with Name, Environment, Terraform = "true"

## Code Quality
- Use 2-space indentation
- Group related resources with blank lines
- Add comments for complex logic
- Follow established file naming patterns in the project

## AWS/EKS Best Practices
- Use least privilege for IAM roles
- Deploy across multiple AZs for HA
- Configure proper EKS authentication in providers

## Security
- Never hardcode secrets or credentials
- Use AWS Secrets Manager for sensitive data
- Implement proper RBAC for Kubernetes
- Apply security groups with minimal access

## Provider Syntax
- Helm provider: use `kubernetes { }` block syntax (NOT `kubernetes = { }`)
- kubectl provider: use `gavinbunney/kubectl` not `hashicorp/kubectl`  
- Configure EKS authentication with exec blocks using api_version "client.authentication.k8s.io/v1beta1"
- Use proper provider aliases for multi-region setups
- Helm provider versions >= 2.5.1 require block syntax for kubernetes configuration
- When Terraform reports "Blocks of type kubernetes are not expected here", check Helm provider version

## Error Handling
- Use proper `depends_on` for resource dependencies
- Handle circular dependencies with data sources appropriately
- Implement lifecycle rules when resources need special handling

## AI-Specific Guidelines
- When generating Terraform code, always include variable descriptions
- Suggest appropriate resource names following project conventions
- Include relevant tags for all AWS resources
- Prefer using existing module patterns over creating new ones
- When asked for fixes, explain the reasoning behind changes
- Consider disaster recovery implications for multi-region deployments
- Validate resource relationships and suggest missing dependencies
- Recommend security best practices for new resources