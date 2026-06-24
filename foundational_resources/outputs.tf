
# -----------------------------------------------------------------------------
# Outputs -- reference these when configuring the AAP AWS credential
# -----------------------------------------------------------------------------

output "aap_iam_access_key_id" {
  description = "Access key ID for the AAP integration IAM user"
  value       = aws_iam_access_key.aap_integration.id
}

output "aap_iam_secret_access_key" {
  description = "Secret access key for the AAP integration IAM user"
  value       = aws_iam_access_key.aap_integration.secret
  sensitive   = true
}
