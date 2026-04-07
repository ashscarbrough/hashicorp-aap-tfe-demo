# output "tfe_hostname" {
#   description = "Fully qualified domain name (FQDN) of the Terraform Enterprise endpoint."
#   value       = aws_route53_record.alias_record.fqdn
# }

# output "alb_dns_name" {
#   description = "DNS name of the Application Load Balancer (ALB) that fronts Terraform Enterprise."
#   value       = aws_lb.tfe.dns_name
# }

output "security_group_ids" {
  description = "Map of security group IDs keyed by component: aap_tfe_demo."
  value = {
    aap_tfe_demo = aws_security_group.aap_tfe_demo.id
  }
}

output "ec2_instance_ip" {
  description = "Private IP address for the EC2 instance hosting Terraform Enterprise."
  value       = aws_instance.aap_tfe_demo_host.private_ip
}

output "secretsmanager_secret_arn_ec2_private_key" {
  description = "ARN of the Secrets Manager secret containing the EC2 host private key."
  value       = aws_secretsmanager_secret.aap_tfe_demo_host_private_key.arn
}

output "ec2_private_key" {
  value     = tls_private_key.aap_tfe_demo_host_key.private_key_openssh
  sensitive = true
}

output "aap_job_id" {
  value       = aap_job.provision
  description = "AAP job ID — use this to find the job run in AAP UI"
}
