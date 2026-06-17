resource "null_resource" "ami_version_tracker" {
  triggers = {
    ami_id = data.hcp_packer_artifact.al2023_demo.external_identifier
  }
}
