
# # Get secrets from Secrets Manager.

# data "aws_iam_policy_document" "aap_tfe_demo_secrets_manager" {
#   statement {
#     effect = "Allow"
#     actions = [
#       "secretsmanager:GetResourcePolicy",
#       "secretsmanager:GetSecretValue",
#       "secretsmanager:DescribeSecret",
#       "secretsmanager:ListSecretVersionIds"
#     ]
#     resources = [
#       "*"
#     ]
#   }
#   statement {
#     effect = "Allow"
#     actions = [
#       "secretsmanager:ListSecrets"
#     ]
#     resources = ["*"]
#   }
# }

# resource "aws_iam_policy" "aap_tfe_demo_secrets_manager" {
#   name   = "SecretsManagerReadAAPTFESecrets"
#   path   = "/"
#   policy = data.aws_iam_policy_document.aap_tfe_demo_secrets_manager.json
# }

# resource "aws_iam_role_policy_attachment" "aap_tfe_demo_secrets_manager" {
#   role       = aws_iam_role.aap_tfe_demo.name
#   policy_arn = aws_iam_policy.aap_tfe_demo_secrets_manager.arn
# }

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
