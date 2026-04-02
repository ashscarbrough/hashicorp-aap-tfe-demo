# Modify EC2 metadata.

data "aws_iam_policy_document" "ec2_modify_metadata" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:ModifyInstanceMetadataOptions"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/*"
    ]
  }
}

resource "aws_iam_policy" "ec2_modify_metadata" {
  name   = "EC2ModifyInstanceMetadataOptions"
  path   = "/"
  policy = data.aws_iam_policy_document.ec2_modify_metadata.json
}

resource "aws_iam_role_policy_attachment" "ec2_modify_metadata" {
  role       = aws_iam_role.tfe.name
  policy_arn = aws_iam_policy.ec2_modify_metadata.arn
}

# Get secrets from Secrets Manager.

data "aws_iam_policy_document" "aap_tfe_demo_secrets_manager" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = [
      aws_db_instance.aap_tfe_demo.master_user_secret[0].secret_arn
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "aap_tfe_demo_secrets_manager" {
  name   = "SecretsManagerReadAAPTFESecrets"
  path   = "/"
  policy = data.aws_iam_policy_document.aap_tfe_demo_secrets_manager.json
}

resource "aws_iam_role_policy_attachment" "aap_tfe_demo_secrets_manager" {
  role       = aws_iam_role.aap_tfe_demo.name
  policy_arn = aws_iam_policy.aap_tfe_demo_secrets_manager.arn
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.aap_tfe_demo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# Create an EC2 instance profile using the aap_tfe_demo role.

data "aws_iam_policy_document" "aap_tfe_demo_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "aap_tfe_demo" {
  name               = var.ec2_iam_role_name
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.aap_tfe_demo_assume_role.json
}

resource "aws_iam_instance_profile" "aap_tfe_demo" {
  name = var.ec2_instance_profile_name
  path = "/"
  role = aws_iam_role.aap_tfe_demo.name
}
