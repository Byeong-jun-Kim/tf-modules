output "homepage_bucket" {
  value = module.homepage_bucket[*].s3_bucket_id
}
output "service_bucket_dev" {
  value = { for k, v in module.service_bucket_dev : k => v.s3_bucket_id }
}
output "service_bucket_prod" {
  value = module.service_bucket_prod[*].s3_bucket_id
}

output "service_domain_name_servers" {
  value = aws_route53_zone.service_zone_prod[*].name_servers
}

output "cloudfront_dev_acm_records" {
  value = { for k, v in module.cloudfront_acm_dev : k => v.acm_certificate_domain_validation_options }
}
output "cloudfront_prod_acm_records" {
  value = module.cloudfront_acm_prod[*].acm_certificate_domain_validation_options
}

output "service_bucket_policy_arn_dev" {
  value = { for k, v in module.service_bucket_iam_policy_dev : k => v.arn }
}
output "service_bucket_policy_arn_prod" {
  value = module.service_bucket_iam_policy_prod[*].arn
}
output "ses_send_email_iam_policy_arn_dev" {
  value = module.ses_send_email_iam_policy_dev[*].arn
}
output "ses_send_email_iam_policy_arn_prod" {
  value = module.ses_send_email_iam_policy_prod[*].arn
}

output "bucket_cloudfront_domain_name_dev" {
  value = { for k, v in module.service_bucket_cloudfront_dev : k => v.cloudfront_distribution_domain_name }
}
output "bucket_cloudfront_domain_name_prod" {
  value = module.service_bucket_cloudfront_prod[*].cloudfront_distribution_domain_name
}
output "bucket_cloudfront_hosted_zone_id_dev" {
  value = { for k, v in module.service_bucket_cloudfront_dev : k => v.cloudfront_distribution_hosted_zone_id }
}
output "bucket_cloudfront_hosted_zone_id_prod" {
  value = module.service_bucket_cloudfront_prod[*].cloudfront_distribution_hosted_zone_id
}
output "homepage_cloudfront_domain_name" {
  value = module.homepage_cloudfront[*].cloudfront_distribution_domain_name
}
output "homepage_cloudfront_hosted_zone_id" {
  value = module.homepage_cloudfront[*].cloudfront_distribution_hosted_zone_id
}
output "loadbalancer_cloudfront_domain_name_dev" {
  value = { for k, v in module.loadbalancer_cloudfront_dev : k => v.cloudfront_distribution_domain_name }
}
output "loadbalancer_cloudfront_domain_name_prod" {
  value = module.loadbalancer_cloudfront_prod[*].cloudfront_distribution_domain_name
}
output "loadbalancer_cloudfront_hosted_zone_id_dev" {
  value = { for k, v in module.loadbalancer_cloudfront_dev : k => v.cloudfront_distribution_hosted_zone_id }
}
output "loadbalancer_cloudfront_hosted_zone_id_prod" {
  value = module.loadbalancer_cloudfront_prod[*].cloudfront_distribution_hosted_zone_id
}
