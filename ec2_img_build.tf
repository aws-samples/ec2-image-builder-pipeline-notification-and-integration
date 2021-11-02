resource "aws_iam_policy" "iam_ec2_img_builder_instance_profile_policy" {
  name        = format("%s-instance-profile-policy", var.tf_resource_prefix)
  path        = "/"
  description = "EC2 Image Builder Instance Profile Policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface",
          "ec2:Describe*",
          "ec2:DetachVolume",
          "ec2:AttachVolume",
          "ec2:DeleteVolume",
          "ec2:CreateVolume",
          "ec2:CreateTags"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role" "ec2_img_builder_instance_profile_role" {
  name = format("%s-instance-profile-role", var.tf_resource_prefix)
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : [
            "ec2.amazonaws.com"
          ]
        },
        "Effect" : "Allow",
      }
    ]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    aws_iam_policy.iam_ec2_img_builder_instance_profile_policy.arn
  ]
  tags = merge(
    {
      "Name" = format("%s-instance-profile-role", var.tf_resource_prefix)
    }
  )
}

resource "aws_iam_instance_profile" "ec2_img_builder_instance_profile" {
  name = format("%s-instance-profile", var.tf_resource_prefix)
  role = aws_iam_role.ec2_img_builder_instance_profile_role.name
}

resource "aws_imagebuilder_image_recipe" "image_recipe_sample" {
  block_device_mapping {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_size           = 50
      volume_type           = "gp2"
    }
  }
  working_directory = "/tmp"
  description       = "sample image recipe"

  component {
    component_arn = data.aws_imagebuilder_component.amazon_cloudwatch_agent_linux.arn
  }
  component {
    component_arn = data.aws_imagebuilder_component.stig_build_linux_high.arn
  }
  component {
    component_arn = data.aws_imagebuilder_component.stig_build_linux_medium.arn
  }
  component {
    component_arn = data.aws_imagebuilder_component.reboot_linux.arn
  }
  component {
    component_arn = data.aws_imagebuilder_component.reboot_test_linux.arn
  }
  component {
    component_arn = data.aws_imagebuilder_component.eni_attachment_test_linux.arn
  }
  component {
    component_arn = data.aws_imagebuilder_component.ebs_volume_usage_test_linux.arn
  }
  component {
    component_arn = data.aws_imagebuilder_component.chrony_time_configuration_test.arn
  }
  component {
    component_arn = data.aws_imagebuilder_component.yum_repository_test_linux.arn
  }

  name         = format("%s-image-recipe", var.tf_resource_prefix)
  parent_image = data.aws_ami.amzn2_ami_latest.id
  version      = "1.0.0"

  tags = merge(
    {
      "Name" = format("%s-image-recipe", var.tf_resource_prefix)
    }
  )
}

resource "aws_imagebuilder_distribution_configuration" "dist_config_sample" {
  name = format("%s-dist-config-sample", var.tf_resource_prefix)

  distribution {
    ami_distribution_configuration {
      ami_tags = {
        "AMIType" = "sample"
        "Latest"  = "True"
      }
      target_account_ids = var.accounts_to_share
      name               = "${var.tf_resource_prefix}-{{ imagebuilder:buildDate }}"
    }

    region = data.aws_region.current.name
  }
}

resource "aws_imagebuilder_infrastructure_configuration" "infra_config_sample" {
  name                          = format("%s-infra-config-sample", var.tf_resource_prefix)
  description                   = "sample ec2 image"
  instance_profile_name         = aws_iam_instance_profile.ec2_img_builder_instance_profile.name
  terminate_instance_on_failure = false
  resource_tags = {
    "AMIType" = "sample"
  }
  tags = merge(
    {
      "Name" = format("%s-infra-config-sample", var.tf_resource_prefix)
    }
  )
}

resource "aws_imagebuilder_image_pipeline" "sample_pipeline" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.image_recipe_sample.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.infra_config_sample.arn
  name                             = format("%s-sample-pipeline", var.tf_resource_prefix)
  enhanced_image_metadata_enabled  = false
  description                      = "sample ec2 image pipeline"
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.dist_config_sample.arn

  schedule {
    schedule_expression = var.pipeline_schedule
  }
  tags = merge(
    {
      "Name" = format("%s-sample-pipeline", var.tf_resource_prefix)
    }
  )
}