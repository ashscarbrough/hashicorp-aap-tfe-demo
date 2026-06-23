# ------------------------------------------------------------------------------
# ASG Lifecycle Hook — triggers AAP runtime config on new liberty-app instances
#
# Flow:
#   1. New instance launches into liberty-app ASG
#   2. ASG pauses instance in Pending:Wait via lifecycle hook
#   3. EventBridge rule fires → triggers Lambda
#   4. Lambda calls AAP job template with ssm_instance_id as extra var
#   5. AAP runs update-liberty-runtime against the specific instance
#   6. Lambda sends CONTINUE → ASG moves instance to InService
#   7. ALB health check confirms Liberty is healthy
# ------------------------------------------------------------------------------

# Zip the Lambda function code
data "archive_file" "liberty_app_asg_lifecycle_webhook" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/asg_lifecycle_webhook"
  output_path = "${path.module}/lambda/liberty_app_asg_lifecycle_webhook.zip"
}

# --- Lambda Function ---
resource "aws_lambda_function" "liberty_app_asg_lifecycle_webhook" {
  function_name    = "liberty-app-asg-lifecycle-webhook"
  filename         = data.archive_file.liberty_app_asg_lifecycle_webhook.output_path
  source_code_hash = data.archive_file.liberty_app_asg_lifecycle_webhook.output_base64sha256
  role             = aws_iam_role.liberty_app_asg_lifecycle_webhook_lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"

  # Timeout must exceed AAP job poll window (40 x 15s = 600s)
  timeout = 630

  environment {
    variables = {
      AAP_HOSTNAME        = var.aap_hostname
      AAP_TOKEN           = var.aap_token
      AAP_JOB_TEMPLATE_ID = var.aap_configuration_job_template_id
      AAP_INVENTORY_ID    = var.aap_inventory_id
    }
  }

  tags = {
    Name      = "liberty-app-asg-lifecycle-webhook"
    ManagedBy = "terraform"
  }
}

# --- ASG Lifecycle Hook ---
resource "aws_autoscaling_lifecycle_hook" "liberty_app_launch" {
  name                   = "liberty-app-launch-hook"
  autoscaling_group_name = aws_autoscaling_group.liberty_app.name
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"

  # How long to wait for Lambda to send CONTINUE before timing out
  # 600s = 10 minutes -- matches Lambda poll timeout (40 x 15s)
  heartbeat_timeout = 600

  # Default action if Lambda times out or sends ABANDON
  default_result = "ABANDON"
}

# ------------------------------------------------------------------------------
# ASG lifecycle hook and EventBridge rule to trigger Lambda on instance launch
# ------------------------------------------------------------------------------

#--- EventBridge Rule ---
# Fires when ASG lifecycle hook transitions to Pending:Wait
resource "aws_cloudwatch_event_rule" "liberty_app_asg_launch" {
  name        = "liberty-app-asg-instance-launch"
  description = "Fires when a new liberty-app ASG instance enters Pending:Wait"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance-launch Lifecycle Action"]
    detail = {
      AutoScalingGroupName = [aws_autoscaling_group.liberty_app.name]
      LifecycleHookName    = [aws_autoscaling_lifecycle_hook.liberty_app_launch.name]
    }
  })
}

# --- EventBridge Target → Lambda ---
resource "aws_cloudwatch_event_target" "liberty_app_asg_trigger" {
  rule = aws_cloudwatch_event_rule.liberty_app_asg_launch.name
  arn  = aws_lambda_function.liberty_app_asg_lifecycle_webhook.arn
}

# --- Lambda Permission for EventBridge ---
resource "aws_lambda_permission" "liberty_app_asg_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.liberty_app_asg_lifecycle_webhook.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.liberty_app_asg_launch.arn
}

# --- CloudWatch Log Group for Lambda ---
resource "aws_cloudwatch_log_group" "liberty_app_asg_lifecycle_webhook" {
  name              = "/aws/lambda/liberty-app-asg-lifecycle-webhook"
  retention_in_days = 7

  tags = {
    Name      = "liberty-app-asg-lifecycle-webhook"
    ManagedBy = "terraform"
  }
}

# --- IAM Role for Lambda ---
resource "aws_iam_role" "liberty_app_asg_lifecycle_webhook_lambda" {
  name = "liberty-app-asg-lifecycle-webhook-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name      = "liberty-app-asg-lifecycle-webhook-lambda"
    ManagedBy = "terraform"
  }
}

# --- IAM Policy for Lambda ---
resource "aws_iam_role_policy" "liberty_app_asg_lifecycle_webhook_lambda" {
  name = "liberty-app-asg-lifecycle-webhook-lambda"
  role = aws_iam_role.liberty_app_asg_lifecycle_webhook_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs -- Lambda execution logs
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # ASG lifecycle -- send CONTINUE or ABANDON back to ASG
        Sid    = "ASGLifecycle"
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:RecordLifecycleActionHeartbeat"
        ]
        Resource = aws_autoscaling_group.liberty_app.arn
      },
      {
        # EC2 describe -- verify instance is SSM-ready before triggering AAP
        Sid    = "EC2Describe"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus"
        ]
        Resource = "*"
      },
      {
        # SSM -- verify instance registration before triggering AAP
        Sid    = "SSMDescribe"
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceInformation"
        ]
        Resource = "*"
      }
    ]
  })
}