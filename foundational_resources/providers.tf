provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aap-tfe-al2023-demo"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

provider "random" {}
