terraform {
  required_version = "~> 0.12"
  required_providers {
    aws      = "~> 2.61"
    template = "~> 2.1"
    tls      = "~> 2.1"
    random   = "~> 2.2"
  }
}

provider "aws" {
  region = var.aws_region
}


