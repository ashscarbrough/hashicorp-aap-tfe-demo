# TLS private key resource to generate SSH key pair for EC2 instance access. 
# The private key will be stored securely in AWS Secrets Manager, and the 
# public key will be used to create an AWS Key Pair for the EC2 instance.

resource "tls_private_key" "aap_tfe_demo_host_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "aap_tfe_demo_host" {
  key_name   = "${var.key_name}-ec2-key"
  public_key = tls_private_key.aap_tfe_demo_host_key.public_key_openssh
}

resource "aws_secretsmanager_secret" "aap_tfe_demo_host_private_key" {
  name                    = "${var.key_name}/ec2-private-key"
  description             = "RSA private key for EC2 SSH access"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "aap_tfe_demo_host_private_key" {
  secret_id     = aws_secretsmanager_secret.aap_tfe_demo_host_private_key.id
  secret_string = tls_private_key.aap_tfe_demo_host_key.private_key_openssh
}


# AWS EC2 instanc
resource "aws_instance" "aap_tfe_demo_host" {
  ami                  = local.ami_id
  instance_type        = local.ec2_instance_type
  key_name             = aws_key_pair.aap_tfe_demo_host.key_name

  user_data            = file(local.user_data_script)
  monitoring           = true

  iam_instance_profile = aws_iam_instance_profile.aap_tfe_demo.name

  associate_public_ip_address = true
  subnet_id            = var.ec2_subnet_id
  vpc_security_group_ids = [aws_security_group.aap_tfe_demo.id]

  lifecycle {
    # SSH keys are injected at instance launch. Recreate the instance if key material changes.
    replace_triggered_by = [aws_key_pair.aap_tfe_demo_host]

    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.run_playbook]
    }
  }

  tags = {
    Name = var.ec2_instance_name
    ManagedBy = "terraform"
  }
}

# Resource to wait for cloud-init to complete on the EC2 instance before allowing Ansible provisioning to proceed. 
# This ensures that the instance is fully initialized and ready to accept SSH connections before we attempt to run any Ansible tasks against it.
resource "null_resource" "wait_for_ssh" {
  triggers = {
    instance_id = aws_instance.aap_tfe_demo_host.id
  }

  connection {
    type        = "ssh"
    host        = aws_instance.aap_tfe_demo_host.public_ip
    user        = local.ansible_ssh_user
    private_key = tls_private_key.aap_tfe_demo_host_key.private_key_openssh
  }

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait"
    ]
  }

  depends_on = [aws_instance.aap_tfe_demo_host]
}
