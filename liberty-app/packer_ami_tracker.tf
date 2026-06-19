# Read the latest artifact from HCP Packer channel
data "hcp_packer_artifact" "liberty_base_demo" {
  bucket_name  = var.hcp_packer_bucket_name
  channel_name = var.hcp_packer_channel_name
  platform     = "aws"
  region       = var.aws_region
}

resource "null_resource" "ami_version_tracker" {
  triggers = {
    ami_id = data.hcp_packer_artifact.al2023_demo.external_identifier
  }
}
