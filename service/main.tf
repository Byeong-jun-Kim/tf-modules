terraform {
  required_version = "1.5.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.82.2"
    }
  }
}

provider "aws" {
  alias   = "prod"
  region  = var.region
  profile = "prod"
}

provider "aws" {
  alias   = "dev"
  region  = var.region
  profile = "default"
}

provider "aws" {
  alias   = "us-east-1_dev"
  region  = "us-east-1"
  profile = "default"
}

provider "aws" {
  alias   = "us-east-1_prod"
  region  = "us-east-1"
  profile = "prod"
}
