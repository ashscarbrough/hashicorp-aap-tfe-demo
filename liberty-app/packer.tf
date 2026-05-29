# Read the latest artifact from HCP Packer channel
data "hcp_packer_artifact" "liberty_app_demo" {
  bucket_name  = var.hcp_packer_bucket_name
  channel_name = var.hcp_packer_channel_name
  platform     = "aws"
  region       = var.aws_region
}