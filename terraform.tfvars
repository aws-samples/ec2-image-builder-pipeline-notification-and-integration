region              = "ap-southeast-1"
tf_resource_prefix  = "ec2-img-builder"
pipeline_schedule   = "cron(0 0 0 ? 1/3 * *)" // Runs every 3 months
accounts_to_share   = []                      // Example: ["111111111111","222222222222"]
notification_email  = "email@abc.com"