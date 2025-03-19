resource "aws_route53_zone" "service_zone_prod" {
  count         = var.dns_enabled ? 1 : 0
  provider      = aws.prod
  name          = var.service_domain
  force_destroy = false
}

resource "aws_route53_record" "service_dev_ns" {
  provider = aws.prod
  for_each = var.dns_enabled ? var.service_domain_dev_prefixes : []
  zone_id  = aws_route53_zone.service_zone_prod[0].zone_id
  name     = each.key
  type     = "NS"
  ttl      = "600"
  records  = aws_route53_zone.service_zones_dev[each.key].name_servers
}

resource "aws_route53_zone" "service_zones_dev" {
  for_each      = var.dns_enabled ? var.service_domain_dev_prefixes : []
  provider      = aws.dev
  name          = "${each.key}.${var.service_domain}"
  force_destroy = false
}
