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
          # Core Session Manager
          "ssm:StartSession",
          "ssm:ResumeSession",
          "ssm:TerminateSession",

          # Run Command (needed for AAP to drive SSM-based playbook execution)
          "ssm:SendCommand",
          "ssm:CancelCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations",
          "ssm:ListCommands",

          # Session logging to S3 and CloudWatch (matches your existing SSM config)
          "s3:PutObject",
          "s3:GetEncryptionConfiguration",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",

          # EC2 Instance Connect (needed for browser-based session fallback)
          "ec2-instance-connect:SendSSHPublicKey"
        ]
        Resource = "*"
      },
      {
        # Scope SSM document access to AWS-provided documents only
        # Prevents this user from executing arbitrary custom documents
        Sid    = "SSMDocumentAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetDocument",
          "ssm:DescribeDocument"
        ]
        Resource = "arn:aws:ssm:*::document/AWS-*"
      }
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

# -----------------------------------------------------------------------------
# Outputs -- reference these when configuring the AAP AWS credential
# -----------------------------------------------------------------------------

output "aap_iam_access_key_id" {
  description = "Access key ID for the AAP integration IAM user"
  value       = aws_iam_access_key.aap_integration.id
}

output "aap_iam_secret_access_key" {
  description = "Secret access key for the AAP integration IAM user"
  value       = aws_iam_access_key.aap_integration.secret
  sensitive   = true
}
