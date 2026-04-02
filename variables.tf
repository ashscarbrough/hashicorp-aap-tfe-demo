# Required

variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources into."
}

variable "environment" {
  type        = string
  description = "The environment name (e.g. dev, staging, prod). Used for tagging."
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC used to host Application."
}

variable "ec2_subnet_id" {
  type = string
  description = "The ID of the subnet the EC2 will be deployed to."
}

variable "route53_zone_name" {
  type        = string
  description = "The name of the Route53 zone used to host the application."
}


# Optional

# VPC

variable "ec2_security_group_name" {
  type        = string
  description = "The name of the EC2 hosts security group."
  default     = "aap-tfe-demo-sg"
}

# variable "alb_security_group_name" {
#   type        = string
#   description = "The name of the Application Load Balancer security group."
#   default     = "aap-tfe-demo-alb-sg"
# }


# EC2

variable "ec2_instance_ami_name" {
  type        = string
  description = "The name of the AMI used as a filter for Application EC2 instances.  approved by HashiCorp security."
  default     = "hc-base-al2023-x86_64"

  validation {
    condition = contains([
      "debian-13-amd64-20251117-2299",
      "hc-base-ubuntu-2204",
      "hc-base-ubuntu-2404-amd64",
      "hc-base-ubuntu-2404-arm64",
      "hc-base-al2023-x86_64",
      "hc-base-al2023-arm64",
      "hc-base-rhel-9-x86_64",
      "hc-base-rhel-9-arm64",
    ], var.ec2_instance_ami_name)
    error_message = "ec2_instance_ami_name must be one of the approved AMI name patterns."
  }
}

variable "ec2_instance_name" {
  type        = string
  description = "The name of the EC2 instance."
  default     = "aap-tfe-demo-ec2-instance"
}

variable "ec2_instance_type" {
  type        = string
  nullable    = true
  description = "The type (size) of the application EC2 instance. Defaults to t3.medium for x86_64 AMIs and t4g.medium for arm64 AMIs."
  default     = null
}

variable "ec2_volume_size" {
  type        = number
  description = "The size in GiB of the root EBS volume attached to each application EC2 instance."
  default     = 25

  validation {
    condition     = var.ec2_volume_size >= 25
    error_message = "The root volume must be at least 20 GiB per default standards."
  }
}

# variable "asg_name" {
#   type        = string
#   description = "The name of the ASG for the application EC2 instances."
#   default     = "aap-tfe-demo-asg"
# }

# variable "asg_min_size" {
#   type        = number
#   description = "The minimum number of application EC2 instances allowed in the auto scaling group."
#   default     = 0
# }

# variable "asg_max_size" {
#   type        = number
#   description = "The maximum number of application EC2 instances allowed in the auto scaling group."
#   default     = 2
# }

# variable "asg_desired_capacity" {
#   type        = number
#   description = "The desired number of application EC2 instances active in the auto scaling group."
#   default     = 2
# }

# variable "lb_name" {
#   type        = string
#   description = "The name of the application load balancer used to distribute HTTPS traffic across application EC2 instances."
#   default     = "aap-tfe-demo-alb"
# }

# variable "lb_target_group_name" {
#   type        = string
#   description = "The name of the target group used to direct HTTPS traffic to application EC2 instances."
#   default     = "aap-tfe-demo-alb-tg"
# }


# IAM
variable "ec2_iam_role_name" {
  type        = string
  description = "The name of the IAM role assigned to the EC2 instance profile assigned to the application EC2 instances."
  default     = "aap-tfe-demo-iam-role"
}

variable "ec2_instance_profile_name" {
  type        = string
  description = "The name of the EC2 instance profile assigned to the application EC2 instances."
  default     = "aap-tfe-demo-instance-profile"
}

# Route53

variable "aap_tfe_demo_subdomain" {
  type        = string
  description = "The subdomain used for the application."
  default     = "aap-tfe-demo"
}