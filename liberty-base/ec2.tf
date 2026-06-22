# TLS private key resource to generate SSH key pair for EC2 instance access. 
# The private key will be stored securely in AWS Secrets Manager, and the 
# public key will be used to create an AWS Key Pair for the EC2 instance.

resource "tls_private_key" "aap_tfe_demo_host_key" {
  count     = var.connect_via_session_manager ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "liberty_base_key_pair" {
  count      = var.connect_via_session_manager ? 0 : 1
  key_name   = "${var.key_name}-ec2-key"
  public_key = tls_private_key.aap_tfe_demo_host_key[0].public_key_openssh
}

resource "aws_secretsmanager_secret" "liberty_base_host_private_key" {
  count                   = var.connect_via_session_manager ? 0 : 1
  name                    = "${var.key_name}/ec2-private-key"
  description             = "RSA private key for EC2 SSH access"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "liberty_base_host_private_key" {
  count         = var.connect_via_session_manager ? 0 : 1
  secret_id     = aws_secretsmanager_secret.liberty_base_host_private_key[0].id
  secret_string = tls_private_key.aap_tfe_demo_host_key[0].private_key_openssh
}

# ── EC2 Instance — remove EIP, keep instance ─────────────────────────────────
# Replace your existing aws_instance with this. The only changes are:
# - associate_public_ip_address dropped to false (ALB is the public endpoint)
# - subnet_id can now be a private subnet if you have one; SSM doesn't need
#   a public IP as long as you have a VPC endpoint or NAT gateway
resource "aws_instance" "liberty_base_host" {
  ami           = data.hcp_packer_artifact.liberty_base_image.external_identifier
  instance_type = var.ec2_instance_type
  key_name      = var.connect_via_session_manager ? null : aws_key_pair.liberty_base_key_pair[0].key_name

  user_data = file("${path.module}/scripts/rhel9-userdata.sh")
  monitoring = true

  iam_instance_profile = aws_iam_instance_profile.liberty_base_instance_profile.name

  # Instance no longer needs a public IP — ALB handles public ingress.
  # SSM connectivity works via VPC endpoint or NAT; does not require public IP.
  associate_public_ip_address = false
  subnet_id                   = var.ec2_subnet_id
  vpc_security_group_ids      = [aws_security_group.liberty_base_instance_sg.id]

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [null_resource.ami_version_tracker]

    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_workflow_job_launch.current_version_playbook_ssm]
    }
  }

  tags = {
    Name           = var.ec2_instance_name
    ManagedBy      = "terraform"
    AnsibleManaged = "true"
    DeploymentPath = "liberty-base"
    AMIVersion     = data.hcp_packer_artifact.liberty_base_image.external_identifier
  }
}

resource "aws_instance" "liberty_base_host" {
  ami                         = data.hcp_packer_artifact.liberty_base_image.external_identifier
  instance_type               = var.ec2_instance_type
  key_name                    = var.connect_via_session_manager ? null : aws_key_pair.liberty_base_key_pair[0].key_name
  user_data                   = file("${path.module}/scripts/rhel9-userdata.sh")
  monitoring                  = true
  associate_public_ip_address = false
  subnet_id                   = var.ec2_subnet_id
  vpc_security_group_ids      = [aws_security_group.liberty_base_instance_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.liberty_base_ec2_instance_profile.name

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Waiting for instance SSM registration before firing AAP job..."

      for i in $(seq 1 20); do
        STATUS=$(aws ssm describe-instance-information \
          --filters "Key=InstanceIds,Values=${self.id}" \
          --query 'InstanceInformationList[0].PingStatus' \
          --region ${var.aws_region} \
          --output text 2>/dev/null || echo "None")

        echo "Attempt $i/20 -- SSM status: $STATUS"

        if [ "$STATUS" = "Online" ]; then
          echo "Instance ${self.id} is SSM-registered and ready"
          exit 0
        fi
        sleep 15
      done

      echo "Timed out waiting for SSM registration after 5 minutes"
      exit 1
    EOT
  }

  tags = {
    Name           = var.ec2_instance_name
    ManagedBy      = "terraform"
    AnsibleManaged = "true"
    AMIVersion     = data.hcp_packer_artifact.liberty_base_image.external_identifier
    DeploymentPath = "liberty-base"
    Environment    = "demo"
    Project        = "aap-tfe-al2023-demo"
  }

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [null_resource.ami_version_tracker]
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_workflow_job_launch.current_version_playbook_ssm]
    }
  }
}