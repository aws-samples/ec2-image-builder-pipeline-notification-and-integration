data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_ami" "amzn2_ami_latest" {
  most_recent = "true"
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["*amzn2-ami-hvm-*-ebs*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
data "aws_imagebuilder_component" "amazon_cloudwatch_agent_linux" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/amazon-cloudwatch-agent-linux/1.0.0"
}

data "aws_imagebuilder_component" "stig_build_linux_high" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/stig-build-linux-high/3.1.0"
}

data "aws_imagebuilder_component" "stig_build_linux_medium" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/stig-build-linux-medium/3.1.0"
}

data "aws_imagebuilder_component" "reboot_linux" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/reboot-linux/1.0.1"
}

data "aws_imagebuilder_component" "reboot_test_linux" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/reboot-test-linux/1.0.0"
}

data "aws_imagebuilder_component" "eni_attachment_test_linux" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/eni-attachment-test-linux/1.0.3"
}

data "aws_imagebuilder_component" "ebs_volume_usage_test_linux" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/ebs-volume-usage-test-linux/1.0.3"
}

data "aws_imagebuilder_component" "chrony_time_configuration_test" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/chrony-time-configuration-test/1.0.0"
}

data "aws_imagebuilder_component" "yum_repository_test_linux" {
  arn = "arn:aws:imagebuilder:${data.aws_region.current.name}:aws:component/yum-repository-test-linux/1.0.0"
}