# TLS private key resource to generate SSH key pair for EC2 instance access. 
# The private key will be stored securely in AWS Secrets Manager, and the 
# public key will be used to create an AWS Key Pair for the EC2 instance.

resource "tls_private_key" "aap_tfe_demo_host_key" {
  count     = var.connect_via_session_manager ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "aap_tfe_demo_host" {
  count      = var.connect_via_session_manager ? 0 : 1
  key_name   = "${var.key_name}-ec2-key"
  public_key = tls_private_key.aap_tfe_demo_host_key[0].public_key_openssh
}

resource "aws_secretsmanager_secret" "aap_tfe_demo_host_private_key" {
  count                   = var.connect_via_session_manager ? 0 : 1
  name                    = "${var.key_name}/ec2-private-key"
  description             = "RSA private key for EC2 SSH access"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "aap_tfe_demo_host_private_key" {
  count         = var.connect_via_session_manager ? 0 : 1
  secret_id     = aws_secretsmanager_secret.aap_tfe_demo_host_private_key[0].id
  secret_string = tls_private_key.aap_tfe_demo_host_key[0].private_key_openssh
}

# AWS EC2 instance
resource "aws_instance" "aap_tfe_demo_host" {
  ami                  = data.hcp_packer_artifact.al2023_demo.external_identifier  # local.ami_id 
  instance_type        = local.ec2_instance_type
  key_name             = var.connect_via_session_manager ? null : aws_key_pair.aap_tfe_demo_host[0].key_name

  user_data            = file(local.user_data_script)
  monitoring           = true

  iam_instance_profile = aws_iam_instance_profile.aap_tfe_demo.name

  associate_public_ip_address = true
  subnet_id            = var.ec2_subnet_id
  vpc_security_group_ids = [aws_security_group.aap_tfe_demo.id]

  lifecycle {
    create_before_destroy = true
    # SSH keys are injected at instance launch. Recreate the instance if key material changes.
    replace_triggered_by = [null_resource.ami_version_tracker]

    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.run_new_version_playbook]
    }
  }

  tags = {
    Name = var.ec2_instance_name
    ManagedBy = "terraform"
    AnsibleManaged = "true"
    AMIVersion     = data.hcp_packer_artifact.al2023_demo.id
  }
}

# Elastic IP — provides a stable public address that survives EC2 instance replacement.
# When create_before_destroy replaces the instance (e.g. new AMI), the EIP reassociates
# to the new instance so the demo URL never changes.
resource "aws_eip" "aap_tfe_demo_host" {
  domain = "vpc"

  tags = {
    Name      = "${var.ec2_instance_name}-eip"
    ManagedBy = "terraform"
  }
}

resource "aws_eip_association" "aap_tfe_demo_host" {
  instance_id   = aws_instance.aap_tfe_demo_host.id
  allocation_id = aws_eip.aap_tfe_demo_host.id
}
