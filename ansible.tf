# Ansible Automation Platform (AAP) resources to manage the EC2 host inventory and provisioning job.

resource "aap_host" "ec2" {
  name         = aws_instance.aap_tfe_demo_host.public_dns
  inventory_id = var.aap_inventory_id
  variables    = jsonencode({
    ansible_host            = aws_instance.aap_tfe_demo_host.public_ip
    ansible_user            = "ec2-user" # Amazon Linux default user.
    ansible_ssh_private_key = data.aws_secretsmanager_secret_version.aap_tfe_demo_host_private_key.secret_string
    ansible_ssh_common_args = "-o StrictHostKeyChecking=no" # Host is replaced frequently.
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
