
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

output "liberty_base_url" {
  description = "Stable ALB URL for the liberty-base demo instance"
  value       = "http://${aws_lb.liberty_base.dns_name}/liberty-demo"
}