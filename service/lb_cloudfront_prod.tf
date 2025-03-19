data "aws_lb" "service_lb_prod" {
  count    = var.service_load_balancer_name_prod != null ? 1 : 0
  provider = aws.prod
  name     = var.service_load_balancer_name_prod
}

module "loadbalancer_cloudfront_prod" {
  count   = var.service_load_balancer_name_prod != null ? 1 : 0
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "4.0.0"
  providers = {
    aws = aws.prod
  }
  aliases = var.service_root_domain ? ["*.${var.service_domain}", var.service_domain] : ["*.${var.service_domain}"]

  enabled             = true
  is_ipv6_enabled     = false
  http_version        = "http2and3"
  price_class         = "PriceClass_200"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    "lb_${var.service_prefix}_prod" = {
      domain_name = data.aws_lb.service_lb_prod[0].dns_name
      vpc_origin_config = {
        vpc_origin_id       = var.service_load_balancer_vpc_origin_id_prod
        origin_read_timeout = var.service_load_balancer_timeout
      }
    }
  }

  default_cache_behavior = {
    target_origin_id           = "lb_${var.service_prefix}_prod"
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
    acm_certificate_arn      = module.cloudfront_acm_prod[0].acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  } : {}

  web_acl_id = var.waf_arn_prod
}

resource "aws_route53_record" "loadbalancer_prod" {
  count    = var.service_load_balancer_name_prod != null && var.dns_enabled ? 1 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = "*"
  type     = "A"
  alias {
    name                   = module.loadbalancer_cloudfront_prod[0].cloudfront_distribution_domain_name
    zone_id                = module.loadbalancer_cloudfront_prod[0].cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "loadbalancer_root_prod" {
  count    = var.service_load_balancer_name_prod != null && var.dns_enabled && var.service_root_domain ? 1 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = ""
  type     = "A"
  alias {
    name                   = module.loadbalancer_cloudfront_prod[0].cloudfront_distribution_domain_name
    zone_id                = module.loadbalancer_cloudfront_prod[0].cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}
