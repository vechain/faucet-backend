data "aws_ssm_parameter" "private_key" {
  name = "/${local.env.environment}/${local.env.project}/private_key"
}
data "aws_ssm_parameter" "recaptcha_secret_key" {
  name = "/${local.env.environment}/${local.env.project}/recaptcha_secret_key"
}

variable "runtime_platform" {
  type = list(object({
    operating_system_family = string
    cpu_architecture        = string
  }))
  default = [{
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }]
}

# Namespace for ECS backend service

module "namespace" {
  source                = "git::git@github.com:/vechain/terraform_infrastructure_modules.git//namespace"
  env                   = local.env.environment
  namespace_name        = local.env.project
  namespace_description = "Namespace for faucet backend service"
  vpc_id                = data.terraform_remote_state.vpc.outputs.vpc_id
  app_name              = "be"
  project               = local.env.project
}

# Security group for ALB

module "alb-sg" {
  source      = "git::git@github.com:/vechain/terraform_infrastructure_modules.git//security-groups"
  env         = local.env.environment
  project     = local.env.project
  name        = "alb"
  description = "Security group for my project"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description      = "Allow HTTP traffic"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      security_groups  = []
    },
    {
      description      = "Allow HTTPS traffic"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      security_groups  = []
    },
    {
      description      = "Allow Dynamodb TCP traffic"
      from_port        = 8000
      to_port          = 8000
      protocol         = "tcp"
      cidr_blocks      = [local.env.vpc_cidr]
      ipv6_cidr_blocks = []
    }
  ]

  egress_rules = [
    {
      description      = "Allow all traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
    }
  ]
}

# Security group for ECS service

module "ecs-sg" {
  source      = "git::git@github.com:/vechain/terraform_infrastructure_modules.git//security-groups"
  env         = local.env.environment
  project     = local.env.project
  name        = "ecs-be"
  description = "Security group for my project"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress_rules = [
    {
      description      = "Allow Dynamodb traffic"
      from_port        = 8000
      to_port          = 8000
      protocol         = "tcp"
      cidr_blocks      = [local.env.vpc_cidr]
      ipv6_cidr_blocks = []
      security_groups  = []
    },
    {
      description      = "Allow HTTP traffic"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = [local.env.vpc_cidr]
      ipv6_cidr_blocks = []
      security_groups  = []
    }
  ]

  egress_rules = [
    {
      description      = "Allow Oubound PostgreSQL traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
    }
  ]

}

# ECS cluster for backend service

module "ecs-cluster" {
  source  = "git::git@github.com:/vechain/terraform_infrastructure_modules.git//ecs_cluster?ref=v.1.0.69"
  env     = local.env.environment
  project = local.env.project
  vpc_id  = data.terraform_remote_state.vpc.outputs.vpc_id
  cidr    = local.env.vpc_cidr
}

# ECS loadbalanced service

module "ecs-lb-service-faucet-be" {
  depends_on                 = [module.ecs-cluster, module.alb-sg, module.ecs-sg]
  source                     = "git::git@github.com:/vechain/terraform_infrastructure_modules.git//ecs-loadbalanced-webservice?ref=v.1.0.69"
  region                     = local.env.region
  vpc_id                     = data.terraform_remote_state.vpc.outputs.vpc_id
  cluster_name               = module.ecs-cluster.name
  autoscale_cluster_name     = module.ecs-cluster.name
  lb_subnets                 = data.terraform_remote_state.vpc.outputs.public_subnets
  load_balancer_type         = "application"
  app_subnets                = data.terraform_remote_state.vpc.outputs.private_subnets
  env                        = local.env.environment
  is_create_repo             = true
  secrets_enable             = false
  assign_public_ip           = false
  app_name                   = "be"
  ssl_policy                 = "ELBSecurityPolicy-TLS-1-2-2017-01"
  ecr_image_tag              = local.env.image_tag
  project                    = local.env.project
  cpu                        = local.env.cpu
  memory                     = local.env.memory
  cidr                       = local.env.vpc_cidr
  container_port             = 8080
  runtime_platform           = var.runtime_platform
  certificate_arn            = module.faucet-domains.certificate_arn
  ecs_sg                     = [module.ecs-sg.security_group_id]
  rule_0_path_pattern        = ["/api/v*", "/api-docs", "/swagger-ui/*"]
  alb_sg                     = [module.alb-sg.security_group_id]
  enable_deletion_protection = true
  namespace_id               = module.namespace.namespace_id
  https_tg_healthcheck_path  = "/requests"
  environment_variables = [
    {
      "name": "NODE_ENV"
      "value": "production"
    },
    {
      "name": "PRIV_KEY"
      "value": data.aws_ssm_parameter.private_key.value
    },
    {
      "name": "CHAIN_TAG"
      "value": "0x27"    
    },
    {
      "name": "FAUCET_PORT"
      "value": "8080"
    },
    {
      "name": "RECAPCHA_SECRET_KEY"
      "value": data.aws_ssm_parameter.recaptcha_secret_key.value
    },
    {
      "name": "FAUCET_CORS"
      "value": "faucet.vecha.in"
    },
    {
      "name": "REVERSE_PROXY"
      "value": "yes"
  },
  ]
  log_metric_filters = [
    {
      name    = "AppUnhealthy",
      pattern = "Application is UNHEALTHY"
    }
  ]

  ####### enable autoscailing #######
  enable_ecs_cpu_based_autoscaling    = true
  enable_ecs_memory_based_autoscaling = true
  min_capacity                        = 1
  max_capacity                        = 1
  target_cpu_value                    = 70
  target_memory_value                 = 70
  disable_scale_in                    = false
  # scale_in_cooldown = 300
  # scale_out_cooldown = 300
  name = "auto-scaling-group"
}
