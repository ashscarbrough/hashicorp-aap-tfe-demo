# oidc.tf

data "tls_certificate" "aap" {
  url = "${var.aap_hostname}/o"
}

resource "aws_iam_openid_connect_provider" "aap" {
  url = "https://${var.aap_hostname}/o"

  client_id_list = [
    "sts.amazonaws.com"   # standard audience for AWS-bound OIDC
  ]

  thumbprint_list = [
    data.tls_certificate.aap.certificates[0].sha1_fingerprint
  ]

  tags = {
    Name        = "aap-oidc-provider"
    ManagedBy   = "terraform"
  }
}

output "aap_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.aap.arn
}