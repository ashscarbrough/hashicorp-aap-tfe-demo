# ------------------------------------------------------------------------------
# ASG lifecycle hook and EventBridge rule to trigger Lambda on instance launch
# ------------------------------------------------------------------------------

# # EventBridge rule — fires on ASG launch events
# resource "aws_cloudwatch_event_rule" "al2023_asg_instance_launch" {
#   name        = "al2023-asg-instance-launch"
#   description = "Fires when ASG launches a new instance"

#   event_pattern = jsonencode({
#     source      = ["aws.autoscaling"]
#     detail-type = ["EC2 Instance-launch Lifecycle Action"]
#     detail = {
#       AutoScalingGroupName = [aws_autoscaling_group.al2023_aap_tfe_demo_asg.name]
#     }
#   })
# }

# resource "aws_cloudwatch_event_target" "aap_asg_trigger" {
#   rule      = aws_cloudwatch_event_rule.al2023_asg_instance_launch.name
#   target_id = "aap-al2023-asg-lifecycle-hook-lambda"
#   arn       = aws_lambda_function.al2023_asg_lifecycle_hook.arn
# }