provider "aws" {
  region = var.region
  default_tags {
    tags = var.provider_tags
  }
}
