# Ansible Automation Platform (AAP) resources to manage the EC2 host inventory and provisioning job.

locals {
  ansible_ssh_user = strcontains(var.ec2_instance_ami_name, "ubuntu") ? "ubuntu" : "ec2-user"
}

resource "aap_host" "ec2" {
  name         = aws_instance.aap_tfe_demo_host.public_dns
  inventory_id = var.aap_inventory_id
  variables    = jsonencode({
    ansible_host            = aws_instance.aap_tfe_demo_host.public_ip
    ansible_user            = local.ansible_ssh_user
    ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  })
}

data "aws_secretsmanager_secret_version" "aap_tfe_demo_host_private_key" {
  secret_id  = aws_secretsmanager_secret.aap_tfe_demo_host_private_key.id
  depends_on = [aws_secretsmanager_secret_version.aap_tfe_demo_host_private_key]
}

resource "aap_job" "provision" {
  job_template_id = var.aap_job_template_id
  inventory_id    = var.aap_inventory_id

  extra_vars = jsonencode({
    target_host = aws_instance.aap_tfe_demo_host.public_ip
  })

  depends_on = [
    aap_host.ec2,
    aws_instance.aap_tfe_demo_host
  ]
}
