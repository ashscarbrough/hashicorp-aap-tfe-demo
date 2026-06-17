# ------------------------------------------------------------
# Required base variables
# ------------------------------------------------------------

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

variable "subnet_public_a_id" {
  type = string
  description = "The ID of the public subnet A used for the Auto Scaling Group."
}

variable "subnet_public_b_id" {
  type = string
  description = "The ID of the public subnet B used for the Auto Scaling Group."
}

# ------------------------------------------------------------
# Required: Ansible Automation Platform ##
# These variables are used to integrate the EC2 instance with 
# AAP, but the demo can be deployed without setting them by 
# leaving them as empty strings or zeroes. See README for details.
# ------------------------------------------------------------
variable "aap_hostname" {
  type        = string
  description = "The hostname or IP address of the AAP instance managing the inventory and job templates. Used for informational purposes in host variables, but not required for connectivity."
}

variable "aap_token" {
  type        = string
  sensitive   = true
  description = "The API token for authenticating to the AAP instance. Required for the Lambda function to trigger Ansible playbook runs, but can be left empty if not using that feature."
}

variable "aap_agent_cidr" {
  type        = string
  description = "The CIDR block representing the network location of the AAP agent(s) that will connect to the EC2 instance. This is used to scope the security group ingress rule allowing SSH access from the AAP agent(s). For example, if the AAP agent is running on a machine with IP address 192.168.1.100, the CIDR block would be 192.168.1.100/32."
}

variable "aap_inventory_id" {
  description = "ID of the AAP inventory to add the host to"
  type        = number
}

variable "aap_new_version_job_template_id" {
  description = "ID of the AAP job template to trigger"
  type        = number
}

variable "aap_rollback_job_template_id" {
  description = "ID of the AAP job template for configure_demo_instance_v1.2.0.yml. Set to a real template ID before using rollback; defaults to 0 (no-op) when rollback is not in use."
  type        = number
  default     = 0
}

# ------------------------------------------------------------
# Optional 
# These variables have default values, but can be customized as needed.
# ------------------------------------------------------------

# ------------------------------------------------------------
# EC2 instance variables
# ------------------------------------------------------------

variable "ec2_security_group_name" {
  type        = string
  description = "The name of the EC2 hosts security group."
  default     = "aap-tfe-al2023-demo-sg"
}

variable "key_name" {
  type        = string
  description = "The name of the key pair used for EC2 SSH access."
  default     = "aap-tfe-al2023-demo"
}

variable "ec2_instance_ami_name" {
  type        = string
  description = "The name of the AMI used as a filter for Application EC2 instances.  approved by HashiCorp security."
  default     = "hc-base-rhel-9-x86_64"

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
  default     = "aap-tfe-al2023-demo"
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
  default     = "aap-tfe-al2023-demo-iam-role"
}

variable "ec2_instance_profile_name" {
  type        = string
  description = "The name of the EC2 instance profile assigned to the application EC2 instances."
  default     = "aap-tfe-al2023-demo-instance-profile"
}

variable "ssm_output_s3_bucket" {
  description = "S3 bucket name for AWS Systems Manager Session Manager to store session logs. Optional, but recommended for auditing and troubleshooting purposes."
  type        = string
  default     = null
}

# ------------------------------------------------------------
# HCP Packer variables
# ------------------------------------------------------------

# variable "aap_tfe_demo_subdomain" {
#   type        = string
#   description = "The subdomain used for the application."
#   default     = "aap-tfe-al2023-demo"
# }

variable "hcp_packer_bucket_name" {
  description = "HCP Packer bucket name"
  type        = string
  default     = "packer-demo-al2023"
}

variable "hcp_packer_channel_name" {
  description = "HCP Packer channel name to read latest artifact from"
  type        = string
  default     = "production"
}

variable "tfe_workspace_id" {
  description = "Id of the workspace in HCP Terraform to trigger when new Packer artifacts are available"
  type        = string
}

variable "tfe_trigger_token" {
  description = "Trigger token for the workspace in HCP Terraform to trigger when new Packer artifacts are available"
  type        = string
}

# ------------------------------------------------------------
# Ansible variables
# ------------------------------------------------------------

variable "packages_to_install" {
  description = "List of packages to install on the VM via Ansible"
  type        = list(object({
    name    = string
    version = optional(string)
  }))
  default     = [
    { name = "python3-pip" }
  ]
}

# ------------------------------------------------------------
# Auto Scaling Group variables
# ------------------------------------------------------------

variable "asg_min_size" {
  description = "Minimum number of instances to maintain in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances to maintain in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_desired_capacity" {
  description = "Desired number of instances to maintain in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_aap_job_template_id" {
  description = "ID of the AAP job template to trigger from the ASG lifecycle hook Lambda function"
  type        = number
}

variable "asg_aap_inventory_id" {
  description = "ID of the AAP inventory source to sync from the ASG lifecycle hook Lambda function"
  type        = number
}
