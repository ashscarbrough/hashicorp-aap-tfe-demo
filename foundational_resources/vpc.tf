# # ------------------------------------------------------------------------------
# # Terraform configuration for foundational network resources, including VPC, 
# # subnets, security groups, and VPC endpoints.
# # ------------------------------------------------------------------------------

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "6.6.0"

#   name = "enterprise-demo-vpc"
#   cidr = "10.0.0.0/16"

#   azs             = data.aws_availability_zones.available.names
#   private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
#   public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

#   enable_nat_gateway = true
#   single_nat_gateway = true

#   enable_dns_support   = true
#   enable_dns_hostnames = true

#   map_public_ip_on_launch = true

#   default_network_acl_egress = [{
#     "action" : "allow",
#     "cidr_block" : "0.0.0.0/0",
#     "from_port" : 0,
#     "protocol" : "-1",
#     "rule_no" : 100, "to_port" : 0
#   }]

#   default_network_acl_ingress = [{
#     "action" : "allow",
#     "cidr_block" : "0.0.0.0/0",
#     "from_port" : 0,
#     "protocol" : "-1",
#     "rule_no" : 100, "to_port" : 0
#   }]
# }

# resource "aws_vpc_endpoint" "s3" {
#   vpc_id       = module.vpc.vpc_id
#   service_name = "com.amazonaws.${data.aws_region.current.region}.s3"

#   tags = {
#     Name = "s3-gateway-endpoint"
#   }
# }

# resource "aws_vpc_endpoint_route_table_association" "public" {
#   route_table_id  = module.vpc.public_route_table_ids[0]
#   vpc_endpoint_id = aws_vpc_endpoint.s3.id
# }

# resource "aws_vpc_endpoint_route_table_association" "private" {
#   route_table_id  = module.vpc.private_route_table_ids[0]
#   vpc_endpoint_id = aws_vpc_endpoint.s3.id
# }

# # Security Group for SSM Interface Endpoints

# resource "aws_security_group" "ssm_endpoints" {
#   name        = "ssm-vpc-endpoints"
#   description = "Allow HTTPS from within the VPC to SSM interface endpoints."
#   vpc_id      = module.vpc.vpc_id

#   tags = {
#     Name = "ssm-vpc-endpoints"
#   }
# }

# resource "aws_vpc_security_group_ingress_rule" "ssm_endpoints_https" {
#   security_group_id = aws_security_group.ssm_endpoints.id
#   description       = "Allow HTTPS from the VPC CIDR to SSM endpoints."

#   cidr_ipv4   = "10.0.0.0/16"
#   ip_protocol = "tcp"
#   from_port   = 443
#   to_port     = 443
# }

# resource "aws_vpc_security_group_egress_rule" "ssm_endpoints" {
#   security_group_id = aws_security_group.ssm_endpoints.id
#   description       = "Allow all outbound traffic from SSM endpoints."

#   cidr_ipv4   = "0.0.0.0/0"
#   ip_protocol = "-1"
# }

# # SSM Interface VPC Endpoints (required for Session Manager on private instances)

# resource "aws_vpc_endpoint" "ssm" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.region}.ssm"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnets
#   security_group_ids  = [aws_security_group.ssm_endpoints.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "ssm"
#   }
# }

# resource "aws_vpc_endpoint" "ssmmessages" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.region}.ssmmessages"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnets
#   security_group_ids  = [aws_security_group.ssm_endpoints.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "ssmmessages"
#   }
# }

# resource "aws_vpc_endpoint" "ec2messages" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.region}.ec2messages"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnets
#   security_group_ids  = [aws_security_group.ssm_endpoints.id]
#   private_dns_enabled = true

#   tags = {
#     Name = "ec2messages"
#   }
# }

# resource "aws_vpc_endpoint" "cloudwatch_logs" {
#   vpc_id              = module.vpc.vpc_id
#   service_name        = "com.amazonaws.${data.aws_region.current.region}.logs"
#   vpc_endpoint_type   = "Interface"
#   subnet_ids          = module.vpc.private_subnets
#   security_group_ids  = [aws_security_group.ssm_endpoints.id]
#   private_dns_enabled = true

#   tags = {
#     Name      = "enterprise-demo-vpc-logs-endpoint"
#     ManagedBy = "terraform"
#   }
# }