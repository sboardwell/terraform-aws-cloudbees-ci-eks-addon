variable "hosted_zone" {
  description = "Amazon Route 53 hosted zone. CloudBees CI applications are configured to use subdomains in this hosted zone."
  type        = string
}

variable "route53_zone_id" {
  description = " Amazon Route 53 hosted zone ID."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources."
  default     = {}
  type        = map(string)
}
