provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aap-tfe-demo"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

provider "random" {}
