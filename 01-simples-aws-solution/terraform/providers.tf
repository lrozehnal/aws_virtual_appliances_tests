terraform {
  required_providers {
    aws = {}
  }
  backend "s3" {
    bucket       = "ludek-terraform-states-buckets"
    key          = "aws_virtual_appliance_test_01/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
}
provider "aws" {
  alias  = "eu-west-2"
  region = "eu-west-2 "
}
