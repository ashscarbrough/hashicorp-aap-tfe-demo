# ------------------------------------------------------------
# Launch Template - defines what each ASG instance should look like
# ------------------------------------------------------------
resource "aws_launch_template" "al2023_aap_tfe_demo_host" {
  name_prefix   = "al2023-asg-demo-host-"
  image_id      = data.hcp_packer_artifact.al2023_demo.external_identifier
  instance_type = local.ec2_instance_type
  user_data     = filebase64(local.user_data_script)

  iam_instance_profile {
    name = aws_iam_instance_profile.aap_tfe_demo.name
  }

  lifecycle {
    create_before_destroy = true
    # SSH keys are injected at instance launch. Recreate the instance if key material changes.
    replace_triggered_by = [aws_key_pair.aap_tfe_demo_host, null_resource.ami_version_tracker] 

    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.run_new_version_playbook]
    }
  }

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [aws_security_group.aap_tfe_demo.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = var.ec2_instance_name
      ManagedBy = "terraform"
      AnsibleManaged = "true"
      DemoType = "asg"
      AMIVersion = data.hcp_packer_artifact.al2023_demo.id
      Environment = "demo"
    }
  }
}

# ------------------------------------------------------------
# Auto Scaling Group - defines how many instances to maintain and where
# ------------------------------------------------------------
resource "aws_autoscaling_group" "al2023_aap_tfe_demo_asg" {
  name                      = "al2023-asg-demo-hosts"

  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  desired_capacity          = var.asg_desired_capacity

  launch_template {
    id      = aws_launch_template.al2023_aap_tfe_demo_host.id
    version = "$Latest"
  }
  vpc_zone_identifier       = [var.subnet_public_a_id, var.subnet_public_b_id]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  wait_for_elb_capacity = var.asg_desired_capacity

  tag {
    key                 = "Name"
    value               = "al2023-asg"
    propagate_at_launch = false
  }
  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------
# Elastic Load Balancer - to distribute traffic across ASG instances
# ------------------------------------------------------------
resource "aws_lb" "al2023_aap_tfe_demo_alb" {
  name               = "al2023-asg-demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.aap_tfe_demo.id]
  subnets            = [var.subnet_public_a_id, var.subnet_public_b_id]

  tags = {
    Name = "al2023-asg-demo-alb"
    ManagedBy = "terraform"
    DemoType = "asg"
  }
}

resource "aws_lb_target_group" "al2023_aap_tfe_demo_tg" {
  name        = "al2023-asg-demo-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = {
    Name = "al2023-asg-demo-tg"
    ManagedBy = "terraform"
    DemoType = "asg"
  }

  deregistration_delay = 30

}

resource "aws_lb_listener" "al2023_aap_tfe_demo_listener" {
  load_balancer_arn = aws_lb.al2023_aap_tfe_demo_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.al2023_aap_tfe_demo_tg.arn
  }
}
