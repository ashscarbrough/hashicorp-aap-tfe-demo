# ------------------------------------------------------------------------------
# AWS Security Group for Application Load Balancer in the AAP TFE demo
# ------------------------------------------------------------------------------

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = "liberty-app-alb-security-group"
  description = "Application Load Balancer Security Group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "liberty-app-alb-security-group"
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


# ------------------------------------------------------------------------------
# AWS Security Group for EC2 instances in the AAP TFE demo
# ------------------------------------------------------------------------------

resource "aws_security_group" "liberty_app" {
  name        = var.ec2_security_group_name
  description = "EC2 Hosts Security Group"
  vpc_id      = var.vpc_id

  tags = {
    Name = var.ec2_security_group_name
  }
}

### Ingress rules for EC2 instances (frontend and backend) - allow SSH and HTTPS from anywhere, and restrict SSH access to HCP Terraform workers and AAP agent
resource "aws_vpc_security_group_ingress_rule" "liberty_app_https" {
  security_group_id = aws_security_group.liberty_app.id
  description       = "Allow HTTPS traffic ingress to the Liberty App Hosts from all networks."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "tcp"
  from_port   = 9080
  to_port     = 9080
}

### Egress rule for EC2 instances - allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "liberty_app" {
  security_group_id = aws_security_group.liberty_app.id
  description       = "Allow all outbound traffic from the Liberty App instances."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
