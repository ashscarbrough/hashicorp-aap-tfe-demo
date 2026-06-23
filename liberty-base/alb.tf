# ------------------------------------------------
# ALB and related resources for the liberty-base demo.
# ------------------------------------------------

# --- ALB ---
resource "aws_lb" "liberty_base" {
  name               = "${var.ec2_instance_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  # ALB requires subnets in at least two AZs
  subnets = var.alb_subnet_ids

  tags = {
    Name      = "${var.ec2_instance_name}-alb"
    ManagedBy = "terraform"
  }
}

# --- Target Group ---
# Points at Liberty's HTTP port. ALB handles the public-facing TLS termination
# so we talk plain HTTP to the instance — no need to deal with Liberty's
# self-signed cert at the ALB layer.
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

  # Shorter deregistration delay for demo — default 300s is painful to watch live
  deregistration_delay = 240

  tags = {
    Name      = "${var.ec2_instance_name}-tg"
    ManagedBy = "terraform"
  }

  depends_on = [null_resource.liberty_base_aap_and_alb_gate]
}

# --- Target Group Attachment ---
resource "aws_lb_target_group_attachment" "liberty_base" {
  target_group_arn = aws_lb_target_group.liberty_base.arn
  target_id        = aws_instance.liberty_base_host.id
  port             = 9080

  depends_on = [null_resource.liberty_base_aap_and_alb_gate]
}

# --- ALB Listener — HTTP → Liberty ---
# For the demo, plain HTTP on port 80 forwarded to Liberty on 9080.
# If you have an ACM cert, swap this for HTTPS and add an HTTP→HTTPS redirect.
resource "aws_lb_listener" "liberty_base_http" {
  load_balancer_arn = aws_lb.liberty_base.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.liberty_base.arn
  }
}
