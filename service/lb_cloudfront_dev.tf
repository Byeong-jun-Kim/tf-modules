data "aws_lb" "service_lb_dev" {
  count    = var.service_load_balancer_name_dev != null ? 1 : 0
  provider = aws.dev
  name     = var.service_load_balancer_name_dev
}

module "loadbalancer_cloudfront_dev" {
  for_each = var.service_load_balancer_name_dev != null ? var.service_domain_dev_prefixes : []
  source   = "terraform-aws-modules/cloudfront/aws"
  version  = "4.0.0"
  providers = {
    aws = aws.dev
  }
  aliases = var.service_root_domain ? ["*.${each.key}.${var.service_domain}", var.service_domain] : ["*.${each.key}.${var.service_domain}"]

  enabled             = true
  is_ipv6_enabled     = false
  http_version        = "http2and3"
  price_class         = "PriceClass_200"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    "lb_${var.service_prefix}_${each.key}" = {
      domain_name = data.aws_lb.service_lb_dev[0].dns_name
      vpc_origin_config = {
        vpc_origin_id       = var.service_load_balancer_vpc_origin_id_dev
        origin_read_timeout = var.service_load_balancer_timeout
      }
    }
  }

  default_cache_behavior = {
    target_origin_id           = "lb_${var.service_prefix}_${each.key}"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id   = "216adef6-5c7f-47e4-b989-5492eafa07d3" # AllViewer
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63" # CORS-with-preflight-and-SecurityHeadersPolicy
    use_forwarded_values       = false
  }

  viewer_certificate = var.cert_enabled ? {
    acm_certificate_arn      = module.cloudfront_acm_dev[each.key].acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  } : {}

  web_acl_id = var.waf_arn_dev
}

resource "aws_route53_record" "loadbalancer_dev" {
  for_each = var.service_load_balancer_name_dev != null && var.dns_enabled ? var.service_domain_dev_prefixes : []
  provider = aws.dev
  zone_id  = aws_route53_zone.service_zones_dev[each.key].zone_id
  name     = "*"
  type     = "A"
  alias {
    name                   = module.loadbalancer_cloudfront_dev[each.key].cloudfront_distribution_domain_name
    zone_id                = module.loadbalancer_cloudfront_dev[each.key].cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "loadbalancer_root_dev" {
  for_each = var.service_load_balancer_name_dev != null && var.dns_enabled && var.service_root_domain ? var.service_domain_dev_prefixes : []
  provider = aws.dev
  zone_id  = aws_route53_zone.service_zones_dev[each.key].zone_id
  name     = ""
  type     = "A"
  alias {
    name                   = module.loadbalancer_cloudfront_dev[each.key].cloudfront_distribution_domain_name
    zone_id                = module.loadbalancer_cloudfront_dev[each.key].cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
