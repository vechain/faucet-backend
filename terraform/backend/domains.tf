locals {
  domain_prefix = "${local.env.environment}.${local.env.project}"
}

module "faucet-domains" {
  source                  = "git@github.com:vechain/terraform_infrastructure_modules.git//route53?ref=v.1.0.71"
  public_zone_name        = "${local.domain_prefix}.vechain.org"
  domain_name             = "${local.env.project}.vechain.org"
  project                 = local.env.project
  env                     = local.env.environment
  records                 = ["${local.domain_prefix}.vechain.org"]
  subdomain_type          = "CNAME"
  create_cert             = true
  # Cert domain will default to env.domain_name (or just domain_name for prod), but can be overriden here.
  cert_domain_override    = "api.${local.domain_prefix}.vechain.org"
}

resource aws_route53_record "backend_cname" {
  zone_id = module.faucet-domains.public_zone_id
  name    = "api.${local.domain_prefix}.vechain.org"
  type    = "CNAME"
  ttl     = 300
  records = [module.ecs-lb-service-faucet-be.alb_dns_name]
}