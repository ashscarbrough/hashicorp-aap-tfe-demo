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

# -----------------------------------------------------------------------------
# Step 1: Pre-job -- sync dynamic inventory so AAP knows about the instance
# before the job launches
# -----------------------------------------------------------------------------

resource "null_resource" "liberty_base_pre_job" {
  triggers = {
    instance_id = aws_instance.liberty_base.id
    ami_id      = data.hcp_packer_artifact.al2023_demo.external_identifier
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Triggering AAP dynamic inventory sync..."

      curl -s --insecure --request POST \
        --header "Authorization: Bearer $${AAP_TOKEN}" \
        --header "Content-Type: application/json" \
        "${var.aap_hostname}/api/controller/v2/inventory_sources/${var.aap_inventory_id}/sync/"

      echo "Waiting for inventory sync to complete..."

      while true; do
        SYNC_STATUS=$(curl -s --insecure \
          --header "Authorization: Bearer $${AAP_TOKEN}" \
          "${var.aap_hostname}/api/controller/v2/inventory_sources/${var.aap_inventory_id}/" \
          | jq -r '.status')

        echo "Inventory sync status: $SYNC_STATUS"

        case "$SYNC_STATUS" in
          successful)
            echo "Inventory sync complete"
            break
            ;;
          failed|error)
            echo "Inventory sync failed"
            exit 1
            ;;
        esac
        sleep 10
      done
    EOT

    environment = {
      AAP_TOKEN = var.aap_token
    }
  }

  depends_on = [aws_instance.liberty_base]

  # Action trigger fires the AAP job after inventory sync completes
  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.current_version_playbook_ssm]
    }
  }
}

# -----------------------------------------------------------------------------
# Step 2: Post-job -- validate Liberty is healthy behind the ALB
# Nothing should depend on the liberty-base instance being ready until
# this resource is satisfied
# -----------------------------------------------------------------------------

resource "null_resource" "liberty_base_post_job" {
  triggers = {
    instance_id = aws_instance.liberty_base.id
    ami_id      = data.hcp_packer_artifact.al2023_demo.external_identifier
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Waiting for liberty-base instance to be healthy behind ALB..."

      aws elbv2 wait target-in-service \
        --target-group-arn ${aws_lb_target_group.liberty_base.arn} \
        --region ${var.aws_region}

      echo "Liberty is healthy -- deployment complete"
    EOT
  }

  # This resource only runs after the pre-job resource completes
  # which means after the action trigger has fired the AAP job
  # The implicit assumption is that by the time Terraform evaluates
  # this resource, the AAP job has had time to run. If you need a
  # harder guarantee, see the note below.
  depends_on = [null_resource.liberty_base_pre_job]
}