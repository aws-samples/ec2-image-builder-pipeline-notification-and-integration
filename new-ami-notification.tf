locals {
  cloud_trail_logs_bucket_name = format("%s-cloudtrail-logs-%s-%s", var.tf_resource_prefix, data.aws_region.current.name, data.aws_caller_identity.current.account_id)
}
resource "aws_iam_policy" "cloudtrail_cw_policy" {
  name = format("%s-cloudtrail-cw-policy", var.tf_resource_prefix)
  path = "/"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_iam_role" "cloudtrail_cw_role" {
  name = format("%s-cloudtrail-cw-role", var.tf_resource_prefix)

  assume_role_policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudtrail.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    aws_iam_policy.cloudtrail_cw_policy.arn,
  ]
}

resource "aws_s3_bucket" "cloud_trail_logs_bucket" {
  bucket        = local.cloud_trail_logs_bucket_name
  force_destroy = true
  policy        = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${local.cloud_trail_logs_bucket_name}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${local.cloud_trail_logs_bucket_name}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_s3_bucket_public_access_block" "cloud_trail_logs_bucket" {
  bucket                  = aws_s3_bucket.cloud_trail_logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
  depends_on = [
    aws_s3_bucket.cloud_trail_logs_bucket
  ]
}

resource "aws_cloudtrail" "cloudtrail" {
  name                          = format("%s-ec2-imb-builder-cloudtrail", var.tf_resource_prefix)
  s3_bucket_name                = aws_s3_bucket.cloud_trail_logs_bucket.id
  s3_key_prefix                 = "cloudtrail_logs"
  include_global_service_events = false
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail_cw_role.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudwatch_log_group_cloudtrail.arn}:*"
}

resource "aws_cloudwatch_log_group" "cloudwatch_log_group_cloudtrail" {
  name = "ec2-img-builder-cloudtrail"
}

resource "aws_iam_policy" "new_ami_notify_lambda_exe_policy" {
  name = format("%s-ami-notify-lambda-exe-policy", var.tf_resource_prefix)
  path = "/"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "arn:aws:logs:*:*:*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "lambda:InvokeFunction"
        ],
        "Resource" : "*"
      },

    ]
  })
}

resource "aws_iam_role" "new_ami_notify_lambda_exe_role" {
  name = format("%s-ami-notify-lambda-exe-role", var.tf_resource_prefix)
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
      }
    ]
  })
  managed_policy_arns = [
    aws_iam_policy.new_ami_notify_lambda_exe_policy.arn,
  ]
}

resource "aws_lambda_function" "new_ami_notification" {
  filename      = "new-ami-notification.py.zip"
  function_name = format("%s-new-ami-notification", var.tf_resource_prefix)
  role          = aws_iam_role.new_ami_notify_lambda_exe_role.arn
  handler       = "new-ami-notification.lambda_handler"

  source_code_hash = filebase64sha256("new-ami-notification.py.zip")

  runtime = "python3.8"

  environment {
    variables = {
      ami_selection_tag_name   = "AMIType"
      ami_selection_tag_values = "sample"
      account_to_share         = join(",", var.accounts_to_share)
    }
  }
}

resource "aws_lambda_permission" "new_ami_notification_allow_cloudwatch" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.new_ami_notification.function_name
  principal     = "sns.amazonaws.com"
}

resource "aws_sns_topic" "new_ami_lambda_trigger" {
  name = format("%s-new-ami-trigger", var.tf_resource_prefix)
}

resource "aws_sns_topic_subscription" "sns_subscription_to_lambda" {
  topic_arn = aws_sns_topic.new_ami_lambda_trigger.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.new_ami_notification.arn
}

resource "aws_sns_topic_subscription" "sns_subscription_to_email" {
  topic_arn = aws_sns_topic.new_ami_lambda_trigger.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_cloudwatch_log_metric_filter" "new_ami_cwlog_metric_filter" {
  name           = format("%s-new-ami-cwlog-metric-filter", var.tf_resource_prefix)
  pattern        = "{ ($.eventName = CreateTags) && ($.userAgent = imagebuilder.amazonaws.com) }"
  log_group_name = aws_cloudwatch_log_group.cloudwatch_log_group_cloudtrail.name

  metric_transformation {
    name      = "EC2ImgBuildNewAMICreatedCount"
    namespace = "CloudTrailMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "new_ami_cwlog_metric_alarm" {
  alarm_name                = format("%s-new-ami-cwlog-metric-alarm", var.tf_resource_prefix)
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "EC2ImgBuildNewAMICreatedCount"
  namespace                 = "CloudTrailMetrics"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "A CloudWatch Alarm that triggers when new AMI is created by the EC2 Image Builder pipeline"
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"
  alarm_actions             = [aws_sns_topic.new_ami_lambda_trigger.arn]
}