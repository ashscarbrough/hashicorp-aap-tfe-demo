
# EC2 Security Groups

resource "aws_security_group" "aap_tfe_demo" {
  name        = var.ec2_security_group_name
  description = "EC2 Hosts Security Group"
  vpc_id      = var.vpc_id

  tags = {
    Name = var.ec2_security_group_name
  }
}

### Ingress rules for EC2 instances (frontend and backend) - allow SSH and HTTPS from anywhere, and restrict SSH access to HCP Terraform workers and AAP agent
resource "aws_vpc_security_group_ingress_rule" "aap_tfe_demo_https" {
  security_group_id = aws_security_group.aap_tfe_demo.id
  description       = "Allow HTTPS traffic ingress to the TFE Hosts from all networks."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

# Allow SSH from AAP workers
resource "aws_vpc_security_group_ingress_rule" "ssh_from_aap" {
  security_group_id = aws_security_group.aap_tfe_demo.id
  description       = "SSH from AAP agent"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.aap_agent_cidr
}

# Allow SSH from HCP Terraform workers
data "http" "hcp_terraform_ip_ranges" {
  url = "https://app.terraform.io/api/meta/ip-ranges"
}

locals {
  hcp_terraform_cidrs = jsondecode(data.http.hcp_terraform_ip_ranges.response_body).terraform
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_hcp_terraform" {
  for_each          = toset(local.hcp_terraform_cidrs)
  security_group_id = aws_security_group.aap_tfe_demo.id
  description       = "SSH from HCP Terraform workers"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}


### Egress rule for EC2 instances - allow all outbound traffic

resource "aws_vpc_security_group_egress_rule" "aap_tfe_demo" {
  security_group_id = aws_security_group.aap_tfe_demo.id
  description       = "Allow all outbound traffic from the AAP TFE demo instances."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
