variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}
variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "vpc_id" {
  type = string
}
variable "private_subnets" {
  type = list(string)
}
variable "intra_subnets" {
  type = list(string)
}
variable "load_balancer_subnets" {
  type    = set(string)
  default = []
}

variable "eks_managed_node_groups" {
  type = any
}

variable "loki_mode" {
  type    = string
  default = "SingleBinary"
}
variable "loki_replicas" {
  type    = number
  default = 3
}
variable "loki_retention" {
  type    = string
  default = "720h"
}
variable "mimir_retention" {
  type    = string
  default = "720h"
}
variable "dns_hosted_zone_arns" {
  type    = list(string)
  default = ["*"]
}
variable "private_dns_zone_name" {
  type    = string
  default = "private.example.com"
}

variable "private_tcp_route" {
  type    = list(number)
  default = [3306]
}

variable "istio_sidecar_enable_default" {
  type    = bool
  default = true
}

variable "botkube_slack_channel" {
  type = string
}
variable "botkube_slack_app_token" {
  type      = string
  sensitive = true
}
variable "botkube_slack_bot_token" {
  type      = string
  sensitive = true
}
variable "fluent_bit_filters" {
  type    = string
  default = ""
}
variable "fluent_bit_outputs" {
  type    = string
  default = ""
}

# https://artifacthub.io/packages/helm/metrics-server/metrics-server
variable "helm_version_metrics_server" {
  type    = string
  default = "3.12.2"
}
# https://artifacthub.io/packages/helm/aws/aws-load-balancer-controller
variable "helm_version_aws_load_balancer_controller" {
  type    = string
  default = "1.10.0"
}
# https://artifacthub.io/packages/helm/external-dns/external-dns
variable "helm_version_external_dns" {
  type    = string
  default = "1.15.0"
}
# https://artifacthub.io/packages/helm/infracloudio/botkube
variable "helm_version_botkube" {
  type    = string
  default = "1.14.0"
}
# https://artifacthub.io/packages/helm/argo/argo-cd
variable "helm_version_argo_cd" {
  type    = string
  default = "7.7.3"
}
# https://artifacthub.io/packages/helm/istio-official/base
variable "helm_version_istio" {
  type    = string
  default = "1.24.0"
}
# https://artifacthub.io/packages/helm/grafana/loki
variable "helm_version_loki" {
  type    = string
  default = "6.19.0"
}
# https://artifacthub.io/packages/helm/fluent/fluent-bit
variable "helm_version_fluent_bit" {
  type    = string
  default = "0.47.10"
}

variable "in_cluster_setting" {
  type    = bool
  default = true
}
variable "gateway_setting" {
  type    = bool
  default = true # false in first time
}
variable "test" {
  type    = bool
  default = false
}
