# ------------------------------------------------
# ALB, ASG and related resources for the liberty-app demo.
# ------------------------------------------------

# --- ALB ---
resource "aws_lb" "liberty_app" {
  name               = "${var.ec2_instance_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = var.alb_subnet_ids

  tags = {
    Name      = "${var.ec2_instance_name}-alb"
    ManagedBy = "terraform"
  }
}

# --- Target Group ---
resource "aws_lb_target_group" "liberty_app" {
  name        = "${var.ec2_instance_name}-tg"
  port        = 9080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/liberty-app/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
    matcher             = "200"
  }

  # Shorter deregistration delay for demo — default 300s is painful to watch live
  deregistration_delay = 30

  tags = {
    Name      = "${var.ec2_instance_name}-tg"
    ManagedBy = "terraform"
  }
}

# --- ALB Listener — HTTP → Liberty ---
resource "aws_lb_listener" "liberty_app_http" {
  load_balancer_arn = aws_lb.liberty_app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.liberty_app.arn
  }
}

# --- Launch Template ---
# Defines the instance configuration the ASG uses to launch new instances.
# Pulls the latest AMI from HCP Packer production channel.
resource "aws_launch_template" "liberty_app" {
  name_prefix   = "${var.ec2_instance_name}-lt-"
  image_id      = data.hcp_packer_artifact.liberty_app_image.external_identifier
  instance_type = var.ec2_instance_type

  # No key pair — SSM Session Manager handles all connectivity
  key_name = var.connect_via_session_manager ? null : var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.liberty_app_ec2_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.liberty_app_instance_sg.id]

  user_data = base64encode(file("${path.module}/scripts/rhel9-userdata.sh"))

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name           = var.ec2_instance_name
      ManagedBy      = "terraform"
      AnsibleManaged = "true"
      DeploymentPath = "liberty-app"
      Environment    = "demo"
      Project        = "aap-tfe-al2023-demo"
      AMIVersion     = data.hcp_packer_artifact.liberty_app_image.external_identifier
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name      = var.ec2_instance_name
      ManagedBy = "terraform"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name      = "${var.ec2_instance_name}-lt"
    ManagedBy = "terraform"
  }
}

# --- Auto Scaling Group ---
# Instances register themselves to the target group on launch.
# The ALB health check gates traffic — instances only receive requests
# once Liberty is healthy on /liberty-app/health.
resource "aws_autoscaling_group" "liberty_app" {
  name                = "${var.ec2_instance_name}-asg"
  desired_capacity    = var.asg_desired_capacity
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  vpc_zone_identifier = var.ec2_subnet_ids

  # Register ASG instances directly with the ALB target group
  target_group_arns = [aws_lb_target_group.liberty_app.arn]

  # Use ELB health checks so the ASG replaces instances the ALB marks unhealthy
  health_check_type         = "ELB"
  health_check_grace_period = 180

  launch_template {
    id      = aws_launch_template.liberty_app.id
    version = "$Latest"
  }

  # Wait for at least one instance to pass the ALB health check before
  # Terraform considers the ASG creation complete
  wait_for_elb_capacity = 1

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 120
    }
  }

  tag {
    key                 = "Name"
    value               = var.ec2_instance_name
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

  tag {
    key                 = "AnsibleManaged"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "DeploymentPath"
    value               = "liberty-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "demo"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "aap-tfe-al2023-demo"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
