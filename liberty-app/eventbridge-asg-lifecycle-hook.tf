# ------------------------------------------------------------------------------
# ASG lifecycle hook and EventBridge rule to trigger Lambda on instance launch
# ------------------------------------------------------------------------------

# EventBridge rule — fires on ASG launch events
resource "aws_cloudwatch_event_rule" "liberty_app_asg_instance_launch" {
  name        = "liberty-app-asg-instance-launch"
  description = "Fires when ASG launches a new instance"

  event_pattern = jsonencode({
    source      = ["aws.autoscaling"]
    detail-type = ["EC2 Instance-launch Lifecycle Action"]
    detail = {
      AutoScalingGroupName = [aws_autoscaling_group.liberty_app.name]
    }
  })
}

resource "aws_cloudwatch_event_target" "liberty_app_asg_trigger" {
  rule      = aws_cloudwatch_event_rule.liberty_app_asg_instance_launch.name
  target_id = "liberty-app-asg-lifecycle-webhook-lambda"
  arn       = aws_lambda_function.liberty_app_asg_lifecycle_webhook.arn
}