
output "vpc_id" {
  description = "VPC Id."
  value       = module.vpc.vpc_id
}
output "vpc_private_subnets" {
  description = "VPC Private Subnets."
  value       = module.vpc.private_subnets
}
