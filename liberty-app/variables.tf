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
  description = "The ID of the VPC used to host the application."
}




variable "ec2_public_subnet_id" {
  type = string
  description = "The ID of the public subnet the EC2 instance will be deployed to."
}

variable "subnet_public_a_id" {
  type = string
  description = "The ID of the public subnet A used for the Auto Scaling Group."
}

variable "subnet_public_b_id" {
  type = string
  description = "The ID of the public subnet B used for the Auto Scaling Group."
}




variable "app_version" {
  type        = string
  description = "Application version to stamp into the EC2 instance via user data script."
  default     = "1.0.0"
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
  default     = ""

  validation {
    condition     = var.connect_via_session_manager || trimspace(var.aap_agent_cidr) != ""
    error_message = "aap_agent_cidr is required when connect_via_session_manager is false. Set connect_via_session_manager=true to use Session Manager without SSH CIDR."
  }
}

variable "aap_inventory_id" {
  description = "ID of the AAP inventory to add the host to"
  type        = number
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
  default     = "liberty-app-sg"
}

variable "key_name" {
  type        = string
  description = "The name of the key pair used for EC2 SSH access."
  default     = "liberty-app"
}

variable "ec2_instance_name" {
  type        = string
  description = "The name of the EC2 instance."
  default     = "liberty-app"
}

variable "ec2_instance_ami_name" {
  type    = string
  default = "liberty-app"
}

variable "ec2_instance_type" {
  type        = string
  nullable    = true
  description = "The type (size) of the application EC2 instance. Defaults to t3.medium for x86_64 AMIs and t4g.medium for arm64 AMIs."
  default     = "t3.medium"
}

variable "ec2_volume_size" {
  type        = number
  description = "The size in GiB of the root EBS volume attached to each application EC2 instance."
  default     = 25

  validation {
    condition     = var.ec2_volume_size >= 25
    error_message = "The root volume must be at least 25 GiB per default standards."
  }
}

# ------------------------------------------------------------
# HCP Packer variables
# ------------------------------------------------------------

variable "hcp_packer_bucket_name" {
  description = "HCP Packer bucket name"
  type        = string
  default     = "immutable-liberty-app-demo"
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

variable "aap_configuration_job_template_id" {
  description = "ID of the AAP job template to trigger"
  type        = number
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

# ------------------------------------------------------------
# Session Manager Connection
# ------------------------------------------------------------

variable "connect_via_session_manager" {
  description = "Whether to connect to the EC2 instance via AWS Systems Manager Session Manager instead of SSH. If true, the Lambda function will use the AWS SDK to start a Session Manager session instead of an SSH session. This requires additional IAM permissions for the Lambda function and SSM agent installed on the EC2 instance, but allows for easier connectivity without managing SSH keys or opening SSH ports in security groups."
  type        = bool
  default     = false
}








variable "ec2_subnet_ids" {
  type = list(string)
  description = "The IDs of the subnets the EC2 instances will be deployed to."
}













variable "alb_subnet_ids" {
  type = list(string)
  description = "The IDs of the subnets to deploy the ALB into. Should be at least 2 for high availability."
}

variable "ec2_instance_ami_name" {
  type    = string
  description = "The name of the AMI to use for the EC2 instance. The data source will look for an AMI with a name that starts with this value."
  default = "rhel9-base"
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
  default     = ""

  validation {
    condition     = var.connect_via_session_manager || trimspace(var.aap_agent_cidr) != ""
    error_message = "aap_agent_cidr is required when connect_via_session_manager is false. Set connect_via_session_manager=true to use Session Manager without SSH CIDR."
  }
}

variable "aap_inventory_source_id" {
  description = "ID of the AAP inventory source to add the host to"
  type        = number
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
  default     = "liberty-base-sg"
}

variable "key_name" {
  type        = string
  description = "The name of the key pair used for EC2 SSH access."
  default     = "liberty-base"
}

variable "ec2_instance_name" {
  type        = string
  description = "The name of the EC2 instance."
  default     = "liberty-base"
}

variable "ec2_instance_type" {
  type        = string
  nullable    = true
  description = "The type (size) of the application EC2 instance. Defaults to t3.medium for x86_64 AMIs and t4g.medium for arm64 AMIs."
  default     = "t3.medium"
}

variable "ec2_volume_size" {
  type        = number
  description = "The size in GiB of the root EBS volume attached to each application EC2 instance."
  default     = 25

  validation {
    condition     = var.ec2_volume_size >= 25
    error_message = "The root volume must be at least 25 GiB per default standards."
  }
}

variable "ec2_iam_role_name" {
  type        = string
  description = "The name of the IAM role to attach to the EC2 instance."
  default     = "liberty-base-ec2-role"
}

variable "ec2_instance_profile_name" {
  type = string
  description = "The name of the EC2 instance profile to attach to the instance."
  default     = "liberty-base-ec2-instance-profile"
}

# ------------------------------------------------------------
# HCP Packer variables
# ------------------------------------------------------------

variable "hcp_packer_bucket_name" {
  description = "HCP Packer bucket name"
  type        = string
  default     = "websphere-liberty-base-demo"
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
