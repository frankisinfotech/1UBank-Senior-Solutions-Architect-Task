terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = "xx-xx-xx"
  access_key = "xx"
  secret_key = "XX"
}
