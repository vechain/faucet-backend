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
    key                  = "facet-app/facet-app-prodvpc.tfstate"
    region               = "eu-west-1"
    workspace_key_prefix = "workspaces"
  }
}

# this module is only needed for prod environment
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "v4.0.1"
  cidr    = local.env.vpc_cidr
  name    = "facet-app-vpc"
  azs     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  # Compact subnetting up to 4 AZs, by up to 4 subnets by x/24 cidr blocks neatly fits in /20 172.31.0.0/16 fits 16 of them
  # AZ's are offset by 4 with subnets if each AZ sequential neighbours
  public_subnets         = concat(local.env.public_subnets)
  private_subnets        = concat(local.env.private_subnets)
  database_subnets       = concat(local.env.database_subnets)
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "prod"
    Terraform   = "true"
    Project     = "faucet-app"
  }
}


output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "public_subnets_cidr_blocks" {
  value = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "private_subnets_cidr_blocks" {
  value = module.vpc.private_subnets_cidr_blocks
}

output "database_subnets" {
  value = module.vpc.database_subnets
}

output "database_subnets_cidr_blocks" {
  value = module.vpc.database_subnets_cidr_blocks
}