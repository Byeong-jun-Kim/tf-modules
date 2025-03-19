resource "aws_ses_domain_identity" "email" {
  count    = var.email_enabled ? 1 : 0
  provider = aws.prod
  domain   = var.service_domain
}
resource "aws_ses_domain_identity" "email_dev" {
  count    = var.email_enabled && length(var.service_domain_dev_prefixes) != 0 ? 1 : 0
  provider = aws.dev
  domain   = var.service_domain
}

resource "aws_ses_domain_dkim" "email" {
  count      = var.email_enabled ? 1 : 0
  provider   = aws.prod
  domain     = aws_ses_domain_identity.email[0].domain
  depends_on = [aws_ses_domain_identity.email]
}
resource "aws_route53_record" "ses_dkim_record" {
  count    = var.email_enabled && var.dns_enabled ? 3 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = "${aws_ses_domain_dkim.email[0].dkim_tokens[count.index]}._domainkey"
  type     = "CNAME"
  ttl      = "600"
  records  = ["${aws_ses_domain_dkim.email[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}
resource "aws_ses_domain_dkim" "email_dev" {
  count      = var.email_enabled && length(var.service_domain_dev_prefixes) != 0 ? 1 : 0
  provider   = aws.dev
  domain     = aws_ses_domain_identity.email_dev[0].domain
  depends_on = [aws_ses_domain_identity.email_dev]
}
resource "aws_route53_record" "ses_dkim_record_dev" {
  count    = var.email_enabled && var.dns_enabled && length(var.service_domain_dev_prefixes) != 0 ? 3 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = "${aws_ses_domain_dkim.email_dev[0].dkim_tokens[count.index]}._domainkey"
  type     = "CNAME"
  ttl      = "600"
  records  = ["${aws_ses_domain_dkim.email_dev[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_ses_domain_mail_from" "email" {
  count            = var.email_enabled ? 1 : 0
  provider         = aws.prod
  domain           = aws_ses_domain_identity.email[0].domain
  mail_from_domain = "${var.ses_mail_from_subdomain}.${var.service_domain}"
  depends_on       = [aws_ses_domain_identity.email]
}
resource "aws_ses_domain_mail_from" "email_dev" {
  count            = var.email_enabled && length(var.service_domain_dev_prefixes) != 0 ? 1 : 0
  provider         = aws.dev
  domain           = aws_ses_domain_identity.email_dev[0].domain
  mail_from_domain = "${var.ses_mail_from_subdomain}.${var.service_domain}"
  depends_on       = [aws_ses_domain_identity.email_dev]
}
resource "aws_route53_record" "ses_spf_record" {
  count    = var.email_enabled && var.dns_enabled ? 1 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = var.ses_mail_from_subdomain
  type     = "TXT"
  ttl      = "600"
  records  = ["v=spf1 include:amazonses.com -all"]
}
resource "aws_route53_record" "ses_mail_from_record" {
  count    = var.email_enabled && var.dns_enabled ? 1 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = var.ses_mail_from_subdomain
  type     = "MX"
  ttl      = "600"
  records  = ["10 feedback-smtp.${var.region}.amazonses.com"]
}

resource "aws_route53_record" "ses_dmarc_record" {
  count    = var.email_enabled && var.dns_enabled ? 1 : 0
  provider = aws.prod
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = "_dmarc"
  type     = "TXT"
  ttl      = "600"
  records  = ["v=DMARC1; p=none; rua=mailto:${var.ses_dmarc_email}"]
}

module "ses_send_email_iam_policy_prod" {
  count   = var.email_enabled ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.1"
  providers = {
    aws = aws.prod
  }
  name = "${var.service_prefix}-email"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = [aws_ses_domain_identity.email[0].arn]
      }
    ]
  })
  depends_on = [aws_ses_domain_identity.email]
}

module "ses_send_email_iam_policy_dev" {
  count   = var.email_enabled && length(var.service_domain_dev_prefixes) != 0 ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.39.1"
  providers = {
    aws = aws.dev
  }
  name = "${var.service_prefix}-email"
  path = "/"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = [aws_ses_domain_identity.email_dev[0].arn]
      }
    ]
  })
  depends_on = [aws_ses_domain_identity.email_dev]
}
