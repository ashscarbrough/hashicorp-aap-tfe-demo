data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "hc-base-ami" {
  filter {
    name   = "name"
    values = ["${var.ec2_instance_ami_name}-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  most_recent = true
  owners      = ["888995627335"]
}

data "aws_kms_key" "secretsmanager" {
  key_id = "alias/aws/secretsmanager"
}

data "aws_kms_key" "ssm" {
  key_id = "alias/aws/ssm"
}

locals {
  account_id                = data.aws_caller_identity.current.account_id
  region                    = data.aws_region.current.region
  route53_alias_record_name = "${var.aap_tfe_demo_subdomain}.${var.route53_zone_name}"
  ami_id                    = data.aws_ami.hc-base-ami.id
  ami_architecture          = strcontains(var.ec2_instance_ami_name, "arm64") ? "arm64" : "x86_64"
  ec2_instance_type         = coalesce(var.ec2_instance_type, local.ami_architecture == "arm64" ? "t4g.medium" : "t3.medium")

  user_data_script = {
    "hc-base-ubuntu-2204"       = "${path.module}/scripts/tfe-host-ubuntu-2204-user-data.sh"
    "hc-base-ubuntu-2404-amd64" = "${path.module}/scripts/tfe-host-ubuntu-2404-user-data.sh"
    "hc-base-ubuntu-2404-arm64" = "${path.module}/scripts/tfe-host-ubuntu-2404-user-data.sh"
    "hc-base-al2023-x86_64"     = "${path.module}/scripts/tfe-host-al2023-user-data.sh"
    "hc-base-al2023-arm64"      = "${path.module}/scripts/tfe-host-al2023-user-data.sh"
    "hc-base-rhel-9-x86_64"     = "${path.module}/scripts/tfe-host-rhel-9-user-data.sh"
    "hc-base-rhel-9-arm64"      = "${path.module}/scripts/tfe-host-rhel-9-user-data.sh"
  }[var.ec2_instance_ami_name]
}

resource "random_string" "tfe_encryption_password" {
  length = 256
}

resource "random_string" "tfe_database_password" {
  length = 64
}

resource "random_string" "tfe_redis_password" {
  length  = 128
  special = false # The Redis auth token doesn't accept special characters.
}
