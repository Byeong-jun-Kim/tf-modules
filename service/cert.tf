module "cloudfront_acm_dev" {
  for_each = var.cert_enabled ? var.service_domain_dev_prefixes : []
  source   = "terraform-aws-modules/acm/aws"
  version  = "5.0.1"
  providers = {
    aws = aws.us-east-1_dev
  }
  domain_name       = "${each.key}.${var.service_domain}"
  validation_method = "DNS"

  subject_alternative_names = ["*.${each.key}.${var.service_domain}"]
  create_route53_records    = false
  # validate_certificate      = false
}

module "cloudfront_acm_records_dev" {
  for_each = var.cert_enabled && var.dns_enabled ? var.service_domain_dev_prefixes : []
  source   = "terraform-aws-modules/acm/aws"
  version  = "5.0.1"
  providers = {
    aws = aws.dev
  }
  create_certificate          = false
  create_route53_records_only = true
  validation_method           = "DNS"

  zone_id                                   = aws_route53_zone.service_zones_dev[each.key].zone_id
  distinct_domain_names                     = module.cloudfront_acm_dev[each.key].distinct_domain_names
  acm_certificate_domain_validation_options = module.cloudfront_acm_dev[each.key].acm_certificate_domain_validation_options
}

module "cloudfront_acm_prod" {
  count   = var.cert_enabled ? 1 : 0
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.1"
  providers = {
    aws = aws.us-east-1_prod
  }
  domain_name       = var.service_domain
  validation_method = "DNS"

  subject_alternative_names = ["*.${var.service_domain}"]
  create_route53_records    = false
  # validate_certificate      = false
}

module "cloudfront_acm_records_prod" {
  count   = var.cert_enabled && var.dns_enabled ? 1 : 0
  source  = "terraform-aws-modules/acm/aws"
  version = "5.0.1"
  providers = {
    aws = aws.prod
  }
  create_certificate          = false
  create_route53_records_only = true
  validation_method           = "DNS"

  zone_id                                   = aws_route53_zone.service_zone_prod[0].zone_id
  distinct_domain_names                     = module.cloudfront_acm_prod[0].distinct_domain_names
  acm_certificate_domain_validation_options = module.cloudfront_acm_prod[0].acm_certificate_domain_validation_options
}
