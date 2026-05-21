terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "shanthosh-terraform-state-2026"
    key            = "infra/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "shanthosh-terraform-locks"
    encrypt        = true
  }
}
