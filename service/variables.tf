variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "service_domain" {
  type    = string
  default = "example.com"
}
variable "service_domain_dev_prefixes" {
  type    = set(string)
  default = []
}

variable "service_prefix" {
  type    = string
  default = "v0"
}
variable "service_root_domain" {
  type    = bool
  default = false
}
variable "service_load_balancer_name_dev" {
  type    = string
  default = null
}
variable "service_load_balancer_vpc_origin_id_dev" {
  type    = string
  default = null
}
variable "service_load_balancer_name_prod" {
  type    = string
  default = null
}
variable "service_load_balancer_vpc_origin_id_prod" {
  type    = string
  default = null
}
variable "service_load_balancer_timeout" {
  type    = number
  default = 30
}
variable "waf_arn_dev" {
  type    = string
  default = null
}
variable "waf_arn_prod" {
  type    = string
  default = null
}

variable "service_bucket_enabled" {
  type    = bool
  default = true
}
variable "bucket_cdn_prefix" {
  type    = string
  default = "cdn"
}
variable "bucket_cdn_exclude" {
  type    = string
  default = "private"
}

variable "repositories" {
  type    = set(string)
  default = []
}
variable "repository_access_arns" {
  type    = list(string)
  default = []
}

variable "homepage_enabled" {
  type    = bool
  default = false
}
variable "homepage_multipage" {
  type    = bool
  default = false
}
variable "homepage_root_domain" {
  type    = bool
  default = false
}
variable "homepage_disable_cache" {
  type    = bool
  default = false
}
variable "homepage_bucket_access_arns" {
  type    = list(string)
  default = []
}
variable "google_site_verification" {
  type    = string
  default = null
}

variable "email_enabled" {
  type    = bool
  default = false
}
variable "ses_mail_from_subdomain" {
  type    = string
  default = "mail"
}
variable "ses_dmarc_email" {
  type    = string
  default = "mailto@example.com"
}

variable "dns_enabled" {
  type    = bool
  default = true
}
variable "cert_enabled" {
  type    = bool
  default = false
}