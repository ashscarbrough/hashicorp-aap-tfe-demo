
output "security_group_ids" {
  description = "Map of security group IDs keyed by component: aap_tfe_demo."
  value = {
    aap_tfe_demo = aws_security_group.aap_tfe_demo.id
  }
}

output "secretsmanager_secret_arn_ec2_private_key" {
  description = "ARN of the Secrets Manager secret containing the EC2 host private key."
  value       = var.connect_via_session_manager ? null : aws_secretsmanager_secret.aap_tfe_demo_host_private_key[0].arn
}

output "ec2_private_key" {
  value     = var.connect_via_session_manager ? null : tls_private_key.aap_tfe_demo_host_key[0].private_key_openssh
  sensitive = true
}

output "packer_webhook_url" {
  description = "Lambda function URL to use as HCP Packer webhook endpoint"
  value       = aws_lambda_function_url.packer_webhook.function_url
}

output "asg_alb_dns_name" {
  description = "ASG ALB DNS name — use this URL for the fleet demo"
  value       = "http://${aws_lb.al2023_aap_tfe_demo_alb.dns_name}/liberty-app"
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.al2023_aap_tfe_demo_asg.name
}
