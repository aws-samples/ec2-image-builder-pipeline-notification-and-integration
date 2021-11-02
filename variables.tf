variable "region" {
  description = "AWS region name"
  type        = string
}

variable "tf_resource_prefix" {
  description = "General prefix for resource names created by terraform"
  type        = string
}

variable "provider_tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    "Terraform" : true
    "environment-name" : "dev"
    "application-name" : "ec2-img-builder"
  }
}

variable "pipeline_schedule" {
  description = "Schedule for the ec2 image pipeline"
  type        = string
}

variable "accounts_to_share" {
  description = "share completed AMI with these accounts"
  type        = list(string)
}
variable "notification_email" {
  description = "notification email address"
  type        = string
}