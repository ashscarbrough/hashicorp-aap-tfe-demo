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
    path                = "/liberty-demo/health"
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

# --- Target Group Attachment ---
resource "aws_lb_target_group_attachment" "liberty_base" {
  target_group_arn = aws_lb_target_group.liberty_base.arn
  target_id        = aws_instance.liberty_base_host.id
  port             = 9080

  # Terraform won't detach (and therefore won't allow destroy of old instance)
  # until the new instance is confirmed healthy
  depends_on = [null_resource.wait_for_alb_healthy]
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

resource "null_resource" "wait_for_alb_healthy" {
  triggers = {
    instance_id = aws_instance.liberty_base_host.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for instance ${aws_instance.liberty_base_host.id} to become healthy..."
      echo "Timeout: 20 minutes (AAP install + Liberty startup)"

      ATTEMPTS=0
      MAX_ATTEMPTS=80  # 80 × 15s = 20 minutes

      until [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; do
        STATE=$(aws elbv2 describe-target-health \
          --target-group-arn ${aws_lb_target_group.liberty_base.arn} \
          --targets Id=${aws_instance.liberty_base_host.id} \
          --region ${var.aws_region} \
          --query 'TargetHealthDescriptions[0].TargetHealth.State' \
          --output text)

        ELAPSED=$((ATTEMPTS * 15))
        echo "[$${ELAPSED}s elapsed] Target health: $STATE"

        if [ "$STATE" = "healthy" ]; then
          echo "Instance healthy after $${ELAPSED}s — old instance safe to destroy"
          exit 0
        fi

        ATTEMPTS=$((ATTEMPTS + 1))
        sleep 15
      done

      echo "ERROR: Instance did not become healthy within 20 minutes"
      exit 1
    EOT
  }

  depends_on = [aws_instance.liberty_base_host]
}
