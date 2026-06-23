# Ansible Automation Platform (AAP) resources to manage the EC2 host inventory and provisioning job.

locals {
  ansible_ssh_user = strcontains(var.ec2_instance_ami_name, "ubuntu") ? "ubuntu" : "ec2-user"
}

# resource "aap_host" "ec2_demo_host" {
#   name         = aws_eip.aap_tfe_demo_host.public_ip
#   inventory_id = var.aap_inventory_id
#   variables    = jsonencode({
#     ansible_host            = aws_eip.aap_tfe_demo_host.public_ip
#     ansible_user            = local.ansible_ssh_user
#     ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
#   })
# }
