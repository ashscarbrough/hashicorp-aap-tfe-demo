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

  tags = {
    Name = var.ec2_instance_name
  }
}

resource "tls_private_key" "aap_tfe_demo_host" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "aap_tfe_demo_host" {
  key_name   = "${var.key_name}-ec2-key"
  public_key = tls_private_key.aap_tfe_demo_host.public_key_openssh
}

resource "aws_secretsmanager_secret" "aap_tfe_demo_host_private_key" {
  name                    = "${var.key_name}/ec2-private-key"
  description             = "ED25519 private key for EC2 SSH access"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "aap_tfe_demo_host_private_key" {
  secret_id     = aws_secretsmanager_secret.aap_tfe_demo_host_private_key.id
  secret_string = tls_private_key.aap_tfe_demo_host.private_key_openssh
}


# resource "aws_launch_template" "app_server" {
#   name                   = "app-asg-lt"
#   image_id               = local.ami_id
#   instance_type          = local.ec2_instance_type
#   update_default_version = true
#   user_data              = base64encode(file(local.user_data_script))

#   monitoring {
#     enabled = true
#   }

#   iam_instance_profile {
#     name = aws_iam_instance_profile.tfe.name
#   }

#   network_interfaces {
#     security_groups = [aws_security_group.tfe.id]
#   }

#   # Separate data volume for Docker (/var/lib/docker).
#   # The AMI root device (/dev/xvda) is left at its default size.
#   # Using /dev/xvdb ensures this is always a distinct, non-root volume.
#   block_device_mappings {
#     device_name = "/dev/xvdb"

#     ebs {
#       volume_type = "gp3"
#       volume_size = var.ec2_volume_size
#       throughput  = 125
#       iops        = 3000
#       encrypted   = true
#     }
#   }

#   metadata_options {
#     http_tokens   = "required"
#     http_endpoint = "enabled"
#   }

#   tag_specifications {
#     resource_type = "instance"

#     tags = {
#       Name = var.ec2_instance_name
#     }
#   }

#   # It is important that the RDS instance is up and running before we try to deploy the TFE Hosts.
#   depends_on = [
#     aws_db_instance.tfe
#   ]
# }

# resource "aws_autoscaling_group" "tfe" {
#   name                      = var.asg_name
#   min_size                  = var.asg_min_size
#   max_size                  = var.asg_max_size
#   desired_capacity          = var.asg_desired_capacity
#   vpc_zone_identifier       = module.vpc.private_subnets
#   health_check_grace_period = 300
#   health_check_type         = "ELB"

#   launch_template {
#     id      = aws_launch_template.tfe.id
#     version = "$Latest"
#   }

#   target_group_arns = [aws_lb_target_group.tfe.id]
# }

# # Application Load Balancer

# resource "aws_lb" "tfe" {
#   name                       = var.lb_name
#   load_balancer_type         = "application"
#   internal                   = false
#   subnets                    = module.vpc.public_subnets
#   security_groups            = [aws_security_group.alb.id]
#   drop_invalid_header_fields = true
# }

# resource "aws_lb_listener" "tfe" {
#   load_balancer_arn = aws_lb.tfe.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = aws_acm_certificate_validation.tfe.certificate_arn

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.tfe.arn
#   }
# }

# resource "aws_lb_target_group" "app_server_tg" {
#   name     = var.lb_target_group_name
#   port     = 443
#   protocol = "HTTPS"
#   vpc_id   = module.vpc.vpc_id

#   health_check {
#     protocol            = "HTTPS"
#     path                = "/_health_check"
#     healthy_threshold   = 2
#     unhealthy_threshold = 10
#     timeout             = 5
#     interval            = 60
#     matcher             = 200
#   }
# }
