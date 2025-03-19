module "service_bucket_dev" {
  for_each = var.service_bucket_enabled ? var.service_domain_dev_prefixes : []
  source   = "terraform-aws-modules/s3-bucket/aws"
  version  = "4.1.2"
  providers = {
    aws = aws.dev
  }
  bucket_prefix = "${replace(replace(var.service_prefix, ".", "-"), "_", "-")}-${replace(replace(each.key, ".", "-"), "_", "-")}-"

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"
  force_destroy            = false

  versioning = {
    status = "Enabled"
  }

  lifecycle_rule = [
    {
      id     = "expire-old-versions"
      status = "Enabled"
      noncurrent_version_expiration = {
        newer_noncurrent_versions = 5
        days                      = 30
      }
    },
  ]

  cors_rule = [
    {
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      allowed_headers = ["*"]
      expose_headers  = []
      max_age_seconds = 3000
    }
  ]
}

module "service_bucket_cloudfront_dev" {
  for_each = var.service_bucket_enabled ? var.service_domain_dev_prefixes : []
  source   = "terraform-aws-modules/cloudfront/aws"
  version  = "3.4.0"
  providers = {
    aws = aws.dev
  }
  aliases = ["${var.bucket_cdn_prefix}.${each.key}.${var.service_domain}"]

  enabled             = true
  is_ipv6_enabled     = false
  http_version        = "http2and3"
  price_class         = "PriceClass_200"
  retain_on_delete    = false
  wait_for_deployment = false
  default_root_object = "index.html"

  create_origin_access_control = true
  origin_access_control = {
    "s3_oac_${var.service_prefix}_${each.key}" = {
      description      = "CloudFront access to S3"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    "s3_oac_${var.service_prefix}_${each.key}" = {
      domain_name           = module.service_bucket_dev[each.key].s3_bucket_bucket_regional_domain_name
      origin_access_control = "s3_oac_${var.service_prefix}_${each.key}"
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_oac_${var.service_prefix}_${each.key}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    use_forwarded_values   = false
  }

  viewer_certificate = var.cert_enabled ? {
    acm_certificate_arn      = module.cloudfront_acm_dev[each.key].acm_certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  } : {}
}

resource "aws_route53_record" "service_bucket_cdn_dev" {
  for_each = var.service_bucket_enabled && var.dns_enabled ? var.service_domain_dev_prefixes : []
  provider = aws.dev
  zone_id  = aws_route53_zone.service_zones_dev[each.key].zone_id
  name     = var.bucket_cdn_prefix
  type     = "A"
  alias {
    name                   = module.service_bucket_cloudfront_dev[each.key].cloudfront_distribution_domain_name
    zone_id                = module.service_bucket_cloudfront_dev[each.key].cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_iam_policy_document" "cdn_service_bucket_policy_dev" {
  for_each = var.service_bucket_enabled ? var.service_domain_dev_prefixes : []
  provider = aws.dev
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${module.service_bucket_dev[each.key].s3_bucket_arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [module.service_bucket_cloudfront_dev[each.key].cloudfront_distribution_arn]
    }
  }
  statement {
    actions   = ["s3:GetObject"]
    effect    = "Deny"
    resources = ["${module.service_bucket_dev[each.key].s3_bucket_arn}/${var.bucket_cdn_exclude}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [module.service_bucket_cloudfront_dev[each.key].cloudfront_distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cdn_service_bucket_policy_dev" {
  for_each = var.service_bucket_enabled ? var.service_domain_dev_prefixes : []
  provider = aws.dev

  bucket = module.service_bucket_dev[each.key].s3_bucket_id
  policy = data.aws_iam_policy_document.cdn_service_bucket_policy_dev[each.key].json
}

module "service_bucket_iam_policy_dev" {
  for_each = var.service_bucket_enabled ? var.service_domain_dev_prefixes : []
  source   = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version  = "5.39.1"
  providers = {
    aws = aws.dev
  }
  name = "${var.service_prefix}-bucket-${each.key}"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:*"]
        Resource = [
          "${module.service_bucket_dev[each.key].s3_bucket_arn}",
          "${module.service_bucket_dev[each.key].s3_bucket_arn}/*"
        ]
      }
    ]
  })
  depends_on = [module.service_bucket_prod]
}
