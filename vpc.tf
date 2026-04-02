
# TFE Instances Security Groups

resource "aws_security_group" "aap_tfe_demo" {
  name        = var.ec2_security_group_name
  description = "EC2 Hosts Security Group"
  vpc_id      = var.vpc_id

  tags = {
    Name = var.ec2_security_group_name
  }
}

resource "aws_vpc_security_group_ingress_rule" "aap_tfe_demo_https" {
  security_group_id = aws_security_group.aap_tfe_demo.id
  description       = "Allow HTTPS traffic ingress to the TFE Hosts from all networks."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "aap_tfe_demo" {
  security_group_id = aws_security_group.aap_tfe_demo.id
  description       = "Allow all outbound traffic from the AAP TFE demo instances."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# # Application Load Balancer Security Group

# resource "aws_security_group" "aap_tfe_demo_app_alb" {
#   name        = var.alb_security_group_name
#   description = "Application Load Balancer Security Group"
#   vpc_id      = var.vpc_id

#   tags = {
#     Name = var.alb_security_group_name
#   }
# }

# resource "aws_vpc_security_group_ingress_rule" "aap_tfe_demo_app_alb" {
#   security_group_id = aws_security_group.aap_tfe_demo_app_alb.id
#   description       = "Allow HTTPS traffic ingress to the application load balancer from all networks."

#   cidr_ipv4   = "0.0.0.0/0"
#   ip_protocol = "tcp"
#   from_port   = 443
#   to_port     = 443
# }

# resource "aws_vpc_security_group_egress_rule" "aap_tfe_demo_app_alb" {
#   security_group_id = aws_security_group.aap_tfe_demo_app_alb.id
#   description       = "Allow all outbound traffic from the application load balancer."

#   cidr_ipv4   = "0.0.0.0/0"
#   ip_protocol = "-1"
# }
