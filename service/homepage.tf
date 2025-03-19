
resource "aws_cloudfront_function" "index_file" {
  count    = var.homepage_enabled && var.homepage_multipage ? 1 : 0
  provider = aws.prod
  name     = "${replace(replace(var.service_prefix, ".", "-"), "_", "-")}-index-file"
  runtime  = "cloudfront-js-1.0"
  code     = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    }
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }
    return request;
}
EOF
}

module "homepage_bucket" {
  count   = var.homepage_enabled ? 1 : 0
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"
  providers = {
    aws = aws.prod
  }
  bucket_prefix = "${replace(replace(var.service_prefix, ".", "-"), "_", "-")}-homepage-"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  force_destroy            = false
}

module "homepage_cloudfront" {
  count   = var.homepage_enabled && var.cert_enabled ? 1 : 0
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.4.0"
  providers = {
    aws = aws.prod
  }
  aliases = var.homepage_root_domain ? ["www.${var.service_domain}", var.service_domain] : ["www.${var.service_domain}"]

  enabled             = true
  is_ipv6_enabled     = false
  http_version        = "http2and3"
  price_class         = "PriceClass_200"
  retain_on_delete    = false
  wait_for_deployment = false
  default_root_object = "index.html"

  create_origin_access_control = true
  origin_access_control = {
    "s3_oac_${var.service_prefix}_homepage" = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    "s3_oac_${var.service_prefix}_homepage" = {
      domain_name           = module.homepage_bucket[0].s3_bucket_bucket_regional_domain_name
      origin_access_control = "s3_oac_${var.service_prefix}_homepage"
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_oac_${var.service_prefix}_homepage"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = var.homepage_disable_cache ? "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" : "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingDisabled / CachingOptimized
    use_forwarded_values   = false

    function_association = var.homepage_multipage ? {
      viewer-request = {
        function_arn = aws_cloudfront_function.index_file[0].arn
      }
    } : {}
  }

  viewer_certificate = var.cert_enabled ? {
    acm_certificate_arn      = module.cloudfront_acm_prod[0].acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  } : {}

  custom_error_response = var.homepage_multipage ? {} : {
    error_caching_min_ttl = 300
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }
}

resource "aws_route53_record" "homepage_a_record" {
  count    = var.homepage_enabled && var.cert_enabled && var.dns_enabled ? 1 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = "www"
  type     = "A"
  alias {
    name                   = module.homepage_cloudfront[0].cloudfront_distribution_domain_name
    zone_id                = module.homepage_cloudfront[0].cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "homepage_root_a_record" {
  count    = var.homepage_enabled && var.cert_enabled && var.dns_enabled && var.homepage_root_domain ? 1 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = ""
  type     = "A"
  alias {
    name                   = module.homepage_cloudfront[0].cloudfront_distribution_domain_name
    zone_id                = module.homepage_cloudfront[0].cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "homepage_google_verification" {
  count    = var.homepage_enabled && var.dns_enabled && var.google_site_verification != null ? 1 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = ""
  type     = "TXT"
  ttl      = "600"
  records  = [var.google_site_verification]
}

data "aws_iam_policy_document" "homepage_bucket_policy" {
  count    = var.homepage_enabled && var.cert_enabled ? 1 : 0
  provider = aws.prod
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.homepage_bucket[0].s3_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [module.homepage_cloudfront[0].cloudfront_distribution_arn]
    }
  }
  statement {
    principals {
      type        = "AWS"
      identifiers = var.homepage_bucket_access_arns
    }
    actions   = ["s3:*"]
    resources = [module.homepage_bucket[0].s3_bucket_arn, "${module.homepage_bucket[0].s3_bucket_arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "homepage_bucket_policy" {
  count    = var.homepage_enabled && var.cert_enabled ? 1 : 0
  provider = aws.prod

  bucket = module.homepage_bucket[0].s3_bucket_id
  policy = data.aws_iam_policy_document.homepage_bucket_policy[0].json
}
