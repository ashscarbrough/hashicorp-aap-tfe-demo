# In liberty-base project
resource "aws_cloudwatch_log_group" "ssm_sessions" {
  name              = "/ssm/session-logs/liberty-base"
  retention_in_days = 7
}
