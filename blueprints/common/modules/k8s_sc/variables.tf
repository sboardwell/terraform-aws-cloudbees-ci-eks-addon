variable "aws_region" {
  description = "AWS region to deploy resources to."
  type        = string
}

variable "create_efs_storage_class" {
  description = "EFS ID."
  type        = bool
  default     = false
}

variable "efs_id" {
  description = "EFS ID."
  type        = string
  default     = null
}
