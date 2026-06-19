# ------------------------------------------------------------------------------
# IAM resources for AL2023 demo
# ------------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.aap_tfe_demo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_read_only" {
  role       = aws_iam_role.aap_tfe_demo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Create an EC2 instance profile using the liberty_base role
data "aws_iam_policy_document" "liberty_base_assume_role" {
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

resource "aws_iam_role" "liberty_base_role" {
  name               = var.ec2_iam_role_name
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.liberty_base_assume_role.json
}

resource "aws_iam_instance_profile" "liberty_base_instance_profile" {
  name = var.ec2_instance_profile_name
  path = "/"
  role = aws_iam_role.liberty_base_role.name
}
