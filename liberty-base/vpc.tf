# ------------------------------------------------------------------------------
# AWS Security Group for Application Load Balancer in the AAP TFE demo
# ------------------------------------------------------------------------------

# --- ALB Security Group ---
# Accepts public HTTP/HTTPS traffic. Instance SG will only allow traffic
# from this SG — not from the internet directly.
resource "aws_security_group" "alb_sg" {
  name        = "${var.ec2_instance_name}-alb-sg"
  description = "Allow inbound HTTP/HTTPS to the liberty-base ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.ec2_instance_name}-alb-sg"
    ManagedBy = "terraform"
  }
}

# ------------------------------------------------------------------------------
# AWS Security Group for EC2 instances in the AAP TFE demo
# ------------------------------------------------------------------------------

resource "aws_security_group" "liberty_base_instance_sg" {
  name        = var.ec2_security_group_name
  description = "EC2 Hosts Security Group"
  vpc_id      = var.vpc_id

  tags = {
    Name = var.ec2_security_group_name
  }
}

# --- Instance Security Group Rule Update ---
# Add a rule to your existing instance SG that allows Liberty port traffic
# only from the ALB SG. Add this to your existing aws_security_group resource
# for the instance, or as standalone ingress rules if your SG is defined
# with separate aws_security_group_rule resources.
resource "aws_security_group_rule" "instance_from_alb_http" {
  type                     = "ingress"
  description              = "Liberty HTTP from ALB only"
  from_port                = 9080
  to_port                  = 9080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.liberty_base_instance_sg.id
  source_security_group_id = aws_security_group.alb_sg.id
}

### Egress rule for EC2 instances - allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "liberty_base_instance" {
  security_group_id = aws_security_group.liberty_base_instance_sg.id
  description       = "Allow all outbound traffic from the Liberty Base instances."

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
