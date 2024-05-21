terraform {
  required_version = "~> 1.8"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.ue1]
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Product    = var.site_domain
      Repository = var.repository
    }
  }
}

provider "aws" {
  alias  = "ue1"
  region = "us-east-1"

  default_tags {
    tags = {
      Product    = var.site_domain
      Repository = var.repository
    }
  }
}
