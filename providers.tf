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

# host and token variables are set in the TF workspace with ANSIBLE_AUTOMATION_PLATFORM_HOST and ANSIBLE_AUTOMATION_PLATFORM_TOKEN
provider "aap" {
  insecure_skip_verify  = true    # AAP is on an internal corporate hostname - almost certainly using a private CA, so we need to skip TLS verification here.
}

provider "random" {}
