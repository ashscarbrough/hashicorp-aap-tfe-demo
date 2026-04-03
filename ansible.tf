# Ansible Automation Platform (AAP) resources to manage the EC2 host inventory and provisioning job.

resource "aap_host" "ec2" {
  name         = aws_instance.main.public_dns
  inventory_id = var.aap_inventory_id
  variables    = jsonencode({
    ansible_host             = aws_instance.main.public_ip
    ansible_user             = "ec2-user"  # The default user for Amazon Linux 2 AMIs is "ec2-user". Adjust if using a different AMI.
    ansible_ssh_private_key  = data.aws_secretsmanager_secret_version.ec2_private_key.secret_string  # Private key will be pulled from Secrets Manager at runtime
    ansible_ssh_common_args  = "-o StrictHostKeyChecking=no"  # the EC2 instance is brand new on each apply, so we need to disable strict host key checking
  })
}

data "aws_secretsmanager_secret_version" "ec2_private_key" {
  secret_id = aws_secretsmanager_secret.ec2_private_key.id
}

resource "aap_job" "provision" {
  job_template_id = var.aap_job_template_id
  inventory_id    = var.aap_inventory_id

  extra_vars = jsonencode({
    target_host = aws_instance.main.public_ip
  })

  depends_on = [
    aap_host.ec2,
    aws_instance.main
  ]
}
