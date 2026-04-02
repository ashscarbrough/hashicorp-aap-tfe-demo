
# Application Settings
resource "aws_ssm_parameter" "tfe_hostname" {
  name        = "/TFE/TFE_HOSTNAME"
  description = "Terraform Enterprise Hostname"
  type        = "SecureString"
  key_id      = data.aws_kms_key.ssm.id
  value       = local.route53_alias_record_name
}

# Object Storage Settings

resource "aws_ssm_parameter" "tfe_object_storage_s3_region" {
  name        = "/TFE/TFE_OBJECT_STORAGE_S3_REGION"
  description = "Terraform Enterprise Object Storage S3 Region"
  type        = "SecureString"
  key_id      = data.aws_kms_key.ssm.id
  value       = data.aws_region.current.region
}

resource "aws_ssm_parameter" "tfe_object_storage_s3_bucket" {
  name        = "/TFE/TFE_OBJECT_STORAGE_S3_BUCKET"
  description = "Terraform Enterprise Object Storage S3 Bucket"
  type        = "SecureString"
  key_id      = data.aws_kms_key.ssm.id
  value       = aws_s3_bucket.tfe.id
}


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
