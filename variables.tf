##### Required #####

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
  description = "The ID of the subnet the EC2 instance will be deployed to."
}


## Required: Ansible Automation Platform ##
variable "aap_agent_cidr" {
  type        = string
  description = "The CIDR block representing the network location of the AAP agent(s) that will connect to the EC2 instance. This is used to scope the security group ingress rule allowing SSH access from the AAP agent(s). For example, if the AAP agent is running on a machine with IP address 192.168.1.100, the CIDR block would be 192.168.1.100/32."
}

variable "aap_inventory_id" {
  description = "ID of the AAP inventory to add the host to"
  type        = number
}

variable "aap_provider_job_template_id" {
  description = "ID of the AAP job template to trigger"
  type        = number
}

variable "aap_tf_actions_job_template_id" {
  description = "ID of the AAP job template to trigger"
  type        = number
}


##### Optional #####

variable "ec2_security_group_name" {
  type        = string
  description = "The name of the EC2 hosts security group."
  default     = "aap-tfe-demo-sg"
}

variable "key_name" {
  type        = string
  description = "The name of the key pair used for EC2 SSH access."
  default     = "aap-tfe-demo"
}

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

variable "aap_tfe_demo_subdomain" {
  type        = string
  description = "The subdomain used for the application."
  default     = "aap-tfe-demo"
}
