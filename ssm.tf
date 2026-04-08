
# SSM Agent Auto-Update Association
#
# Runs AWS-UpdateSSMAgent on all instances tagged ManagedBy=terraform at
# registration time and weekly thereafter, ensuring the SSM agent is always
# up to date without requiring user-data changes or AMI rebakes.

resource "aws_ssm_association" "update_ssm_agent" {
  name                        = "AWS-UpdateSSMAgent"
  association_name            = "update-ssm-agent"
  apply_only_at_cron_interval = false # Also runs immediately when instance registers

  schedule_expression = "rate(7 days)"

  targets {
    key    = "tag:ManagedBy"
    values = ["terraform"]
  }
}
