module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.0"

  #Important: Application Services Hostname must be the same as the domain name or subject_alternative_names
  domain_name = var.hosted_zone
  subject_alternative_names = [
    "*.${var.hosted_zone}" # For subdomains example.${var.domain_name}
  ]

  #https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html
  zone_id           = var.route53_zone_id
  validation_method = "DNS"

  tags = var.tags
}