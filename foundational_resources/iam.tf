resource "aws_iam_role" "packer_build_role" {
  name = "packer-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "packer_s3_access" {
  name = "packer-s3-access"
  role = aws_iam_role.packer_build_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "arn:aws:s3:::ams-hashicorp-artifacts/liberty/*"
    }]
  })
}

resource "aws_iam_instance_profile" "packer_build_profile" {
  name = "packer-build-profile"
  role = aws_iam_role.packer_build_role.name
}
