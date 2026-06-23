# ------------------------------------------------
# ALB and related resources for the liberty-base demo.
# ------------------------------------------------

# --- ALB ---
resource "aws_lb" "liberty_base" {
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
resource "aws_lb_target_group" "liberty_base" {
  name        = "${var.ec2_instance_name}-tg"
  port        = 9080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/liberty-base/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }

  # Deregistration delay is effectively irrelevant on single-instance
  # create_before_destroy replacements since the old instance is destroyed
  # immediately after the new one is stood up. Kept short for demo clarity.
  deregistration_delay = 30

  tags = {
    Name      = "${var.ec2_instance_name}-tg"
    ManagedBy = "terraform"
  }
}

# --- Target Group Attachment ---
# Depends implicitly on aws_instance.liberty_base_host via target_id.
# The instance lifecycle has wait_for_completion = true on its action_trigger
# so by the time this attachment is created Liberty is already installed
# and serving traffic -- the ALB health check passes almost immediately.
resource "aws_lb_target_group_attachment" "liberty_base" {
  target_group_arn = aws_lb_target_group.liberty_base.arn
  target_id        = aws_instance.liberty_base_host.id
  port             = 9080
}

# --- ALB Listener ---
resource "aws_lb_listener" "liberty_base_http" {
  load_balancer_arn = aws_lb.liberty_base.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.liberty_base.arn
  }
}
