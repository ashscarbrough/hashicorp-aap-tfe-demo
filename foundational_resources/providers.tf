provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "foundational-private-account"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

provider "random" {}
