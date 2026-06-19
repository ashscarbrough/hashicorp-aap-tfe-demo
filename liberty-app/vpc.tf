# ------------------------------------------------------------------------------
# AWS Security Group for Application Load Balancer in the AAP TFE demo
# ------------------------------------------------------------------------------

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = "tfe-aap-alb-security-group"
  description = "Application Load Balancer Security Group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "tfe-aap-alb-security-group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS traffic ingress to the application load balancer from all networks."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 9080
  to_port     = 9080
}

resource "aws_vpc_security_group_egress_rule" "alb" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic from the application load balancer."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
