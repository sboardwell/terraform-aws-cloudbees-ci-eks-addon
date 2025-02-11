variable "vpc_name" {
  description = "VPC name."
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources."
  default     = {}
  type        = map(string)
}
