
output "security_group_ids" {
  description = "Map of security group IDs keyed by component: aap_tfe_demo."
  value = {
    aap_tfe_demo = aws_security_group.aap_tfe_demo.id
  }
}

output "ec2_instance_ip" {
  description = "Private IP address of the demo EC2 instance."
  value       = aws_instance.aap_tfe_demo_host.private_ip
}

output "ec2_public_ip" {
  description = "Elastic IP address of the demo EC2 instance. This address is stable across instance replacements."
  value       = aws_eip.aap_tfe_demo_host.public_ip
}

output "secretsmanager_secret_arn_ec2_private_key" {
  description = "ARN of the Secrets Manager secret containing the EC2 host private key."
  value       = aws_secretsmanager_secret.aap_tfe_demo_host_private_key.arn
}

output "ec2_private_key" {
  value     = tls_private_key.aap_tfe_demo_host_key.private_key_openssh
  sensitive = true
}

output "packer_webhook_url" {
  description = "Lambda function URL to use as HCP Packer webhook endpoint"
  value       = aws_lambda_function_url.packer_webhook.function_url
}

output "asg_alb_dns_name" {
  description = "ASG ALB DNS name — use this URL for the fleet demo"
  value       = "http://${aws_lb.al2023_aap_tfe_demo_alb.dns_name}"
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.al2023_aap_tfe_demo_asg.name
}
