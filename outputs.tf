output "tfe_hostname" {
  description = "Fully qualified domain name (FQDN) of the Terraform Enterprise endpoint."
  value       = aws_route53_record.alias_record.fqdn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (ALB) that fronts Terraform Enterprise."
  value       = aws_lb.tfe.dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling group for Terraform Enterprise instances."
  value       = aws_autoscaling_group.tfe.name
}

output "rds_endpoint" {
  description = "RDS endpoint hostname for the PostgreSQL database."
  value       = aws_db_instance.tfe.address
}

output "elasticache_primary_endpoint" {
  description = "Primary endpoint address of the ElastiCache Redis replication group."
  value       = aws_elasticache_replication_group.tfe.primary_endpoint_address
}

output "s3_bucket_id" {
  description = "Name (ID) of the S3 bucket used for Terraform Enterprise object storage."
  value       = aws_s3_bucket.tfe.id
}

output "security_group_ids" {
  description = "Map of security group IDs keyed by component: tfe, alb."
  value = {
    tfe = aws_security_group.tfe.id
    alb = aws_security_group.alb.id
  }
}
