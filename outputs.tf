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
