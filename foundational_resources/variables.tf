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

# ------------------------------------------------------------
# Optional 
# These variables have default values, but can be customized as needed.
# ------------------------------------------------------------
