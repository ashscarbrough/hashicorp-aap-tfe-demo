
output "security_group_ids" {
  description = "Map of security group IDs keyed by component: liberty_app."
  value = {
    liberty_app = aws_security_group.liberty_app_instance_sg.id
  }
}

output "secretsmanager_secret_arn_ec2_private_key" {
  description = "ARN of the Secrets Manager secret containing the EC2 host private key."
  value       = var.connect_via_session_manager ? null : aws_secretsmanager_secret.liberty_app_host_private_key[0].arn
}

output "ec2_private_key" {
  value     = var.connect_via_session_manager ? null : tls_private_key.liberty_app_host_key[0].private_key_openssh
  sensitive = true
}

output "packer_webhook_url" {
  description = "Lambda function URL to use as HCP Packer webhook endpoint"
  value       = aws_lambda_function_url.packer_webhook.function_url
}

output "asg_alb_dns_name" {
  description = "ASG ALB DNS name — use this URL for the fleet demo"
  value       = "http://${aws_lb.liberty_app.dns_name}/liberty-app"
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.liberty_app.name
}
