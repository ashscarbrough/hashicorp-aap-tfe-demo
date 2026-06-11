# Create the IAM User
resource "aws_iam_user" "new_user" {
  name          = "aap-demo-user"
  path          = "/users/"
  force_destroy = true # Allows deleting the user even if they have unmanaged keys/policies
}

# Attach an IAM Managed Policy (e.g., ReadOnly Access)
resource "aws_iam_user_policy_attachment" "read_only_attach" {
  user       = aws_iam_user.new_user.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "ssm_session_access_attach" {
  user       = aws_iam_user.new_user.name
  policy_arn = "arn:aws:iam::153772056435:policy/ssm-session-access"
}

resource "aws_iam_policy" "aap_dynamic_inventory" {
  name        = "aap-dynamic-inventory"
  description = "Allows AAP EC2 dynamic inventory plugin to discover instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2DynamicInventory"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeImages",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeTags",
          "ec2:DescribeAddresses",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      },
      {
        Sid    = "ASGDynamicInventory"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "STSForCredentials"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "aap_dynamic_inventory" {
  user       = aws_iam_user.new_user.name
  policy_arn = aws_iam_policy.aap_dynamic_inventory.arn
}