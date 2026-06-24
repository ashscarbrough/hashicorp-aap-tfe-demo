# -----------------------------------------------------------------------------
# IAM User: AAP Integration
# Covers:
#   - AWS Dynamic Inventory plugin (via ReadOnlyAccess managed policy)
#   - SSM Session Manager (start/resume/terminate sessions + send commands)
# -----------------------------------------------------------------------------

resource "aws_iam_user" "aap_integration" {
  name = "aap-integration"
  path = "/demo/"

  tags = {
    Purpose     = "AAP dynamic inventory and SSM Session Manager access"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}

# -----------------------------------------------------------------------------
# Attach AWS managed ReadOnlyAccess policy
# Covers all ec2:Describe* the dynamic inventory plugin needs, plus broad
# read access across services for future demo additions
# -----------------------------------------------------------------------------

resource "aws_iam_user_policy_attachment" "aap_readonly" {
  user       = aws_iam_user.aap_integration.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# -----------------------------------------------------------------------------
# Inline policy: SSM Session Manager write-side permissions
# ReadOnlyAccess covers ssm:Describe* and ssm:Get* but not the actions
# needed to actually start, send commands, or terminate sessions
# -----------------------------------------------------------------------------

resource "aws_iam_user_policy" "aap_ssm_sessions" {
  name = "aap-ssm-session-manager"
  user = aws_iam_user.aap_integration.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMSessionManager"
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:ResumeSession",
          "ssm:TerminateSession",
          "ssm:SendCommand",
          "ssm:CancelCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "SSMDocumentAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetDocument",
          "ssm:DescribeDocument"
        ]
        Resource = "arn:aws:ssm:*::document/AWS-*"
      },
      {
        # SSM connection plugin uses S3 as transport for Ansible modules
        # Needs full read/write/delete on the SSM session prefix
        Sid    = "SSMSessionS3Transport"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::ams-hashicorp-artifacts",
          "arn:aws:s3:::ams-hashicorp-artifacts/*"
        ]
      },
      {
        Sid    = "CloudWatchSessionLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Sid    = "DeploymentMetadataWrite"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:DeleteParameter"
        ]
        Resource = "*"
      },
    ]
  })
}

# -----------------------------------------------------------------------------
# Access key -- stored in Terraform state
# Treat state as sensitive; use remote state with encryption (HCP Terraform
# encrypts state at rest by default)
# -----------------------------------------------------------------------------

resource "aws_iam_access_key" "aap_integration" {
  user = aws_iam_user.aap_integration.name
}
