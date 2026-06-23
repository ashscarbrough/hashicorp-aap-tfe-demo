
output "security_group_ids" {
  description = "Map of security group IDs keyed by component: liberty_base."
  value = {
    liberty_base = aws_security_group.liberty_base_instance_sg.id
  }
}

output "alb_security_group_id" {
  description = "Security group ID for the ALB in the liberty-base demo."
  value       = aws_security_group.alb_sg.id
}

output "secretsmanager_secret_arn_ec2_private_key" {
  description = "ARN of the Secrets Manager secret containing the EC2 host private key."
  value       = var.connect_via_session_manager ? null : aws_secretsmanager_secret.liberty_base_host_private_key[0].arn
}

output "ec2_private_key" {
  value     = var.connect_via_session_manager ? null : tls_private_key.liberty_base_host_key[0].private_key_openssh
  sensitive = true
}

output "packer_webhook_url" {
  description = "Lambda function URL to use as HCP Packer webhook endpoint"
  value       = aws_lambda_function_url.packer_webhook.function_url
}

output "liberty_base_url" {
  description = "Stable ALB URL for the liberty-base demo instance"
  value       = "http://${aws_lb.liberty_base.dns_name}/liberty-demo"
}

output "alb_dns_name" {
  description = "DNS name of the ALB in the liberty-base demo, which is used as the application endpoint and passed to Ansible for configuration."
  value       = "http://${aws_lb.liberty_base.dns_name}/liberty-demo"
}