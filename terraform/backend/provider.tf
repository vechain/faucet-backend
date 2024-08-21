provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      Terraform = "true"
      Project   = "faucet-app"
    }
  }
}

terraform {
  backend "s3" {
    key                  = "faucet-app/faucet-app-backend.tfstate"
    region               = "eu-west-1"
    workspace_key_prefix = "workspaces"
  }
}

# Import outputs from the vpc module
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "faucet-app-terraform-state-prod"
    key    = "workspaces/prod/faucet-app/faucet-app-prodvpc.tfstate"
    region = "eu-west-1"
  }
}
