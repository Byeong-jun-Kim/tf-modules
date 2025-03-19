resource "kubernetes_namespace" "ingress_gateway" {
  count = var.gateway_setting ? 1 : 0
  metadata {
    name = "ingress-gateway"
  }
  depends_on = [module.eks_cluster]
}

data "aws_subnet" "gateway" {
  for_each = var.gateway_setting ? var.load_balancer_subnets : []
  id       = each.value
}
locals {
  load_balancer_name = "${var.cluster_name}-gateway"
}
resource "helm_release" "gateway" {
  count      = var.gateway_setting ? 1 : 0
  name       = "gateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.helm_version_istio
  namespace  = kubernetes_namespace.ingress_gateway[0].metadata[0].name

  values = [
    <<EOF
service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-port: "15021"
    external-dns.alpha.kubernetes.io/hostname: "*.${var.private_dns_zone_name}"
    service.beta.kubernetes.io/aws-load-balancer-subnets: ${join(", ", var.load_balancer_subnets)}
    service.beta.kubernetes.io/aws-load-balancer-name: ${local.load_balancer_name}
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: topology.kubernetes.io/zone
          operator: In
          values: ${jsonencode([for subnet in data.aws_subnet.gateway : subnet.availability_zone])}
EOF
  ]
  # TODO
  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }
  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }
  depends_on = [helm_release.istiod]
}

resource "kubernetes_manifest" "gateway" {
  count = var.gateway_setting ? 1 : 0
  manifest = {
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "Gateway"
    "metadata" = {
      "name"      = "gateway"
      "namespace" = kubernetes_namespace.ingress_gateway[0].metadata[0].name
    }
    "spec" = {
      "gatewayClassName" = "istio"
      "listeners" = [{
        "name"     = "http"
        "port"     = 80
        "protocol" = "HTTP"
        "allowedRoutes" = {
          "namespaces" = {
            "from" = "All"
          }
        }
      }]
      "addresses" = [{
        "value" = "${helm_release.gateway[0].name}.${kubernetes_namespace.ingress_gateway[0].metadata[0].name}.svc.cluster.local"
        "type"  = "Hostname"
      }]
    }
  }
}

data "aws_lb" "gateway" {
  count      = var.gateway_setting ? 1 : 0
  name       = local.load_balancer_name
  # depends_on = [helm_release.gateway]
}

resource "random_id" "gateway" {
  count = var.gateway_setting ? 1 : 0
  keepers = {
    gateway = data.aws_lb.gateway[0].arn
  }
  byte_length = 8
}

resource "aws_cloudfront_vpc_origin" "gateway" {
  count = var.gateway_setting ? 1 : 0
  vpc_origin_endpoint_config {
    name                   = "${local.load_balancer_name}-${random_id.gateway[0].hex}"
    arn                    = data.aws_lb.gateway[0].arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"
    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
  timeouts {
    create = "30m"
  }
  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [random_id.gateway[0].hex]
  }
}

resource "kubernetes_manifest" "loki_route" {
  count = var.gateway_setting ? 1 : 0
  manifest = {
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "HTTPRoute"
    "metadata" = {
      "name"      = "loki-route"
      "namespace" = kubernetes_namespace.observability[0].metadata[0].name
    }
    "spec" = {
      "parentRefs" = [{
        "name"      = kubernetes_manifest.gateway[0].manifest.metadata.name
        "namespace" = kubernetes_namespace.ingress_gateway[0].metadata[0].name
      }]
      "hostnames" = ["loki.${var.private_dns_zone_name}"]
      "rules" = [{
        "backendRefs" = [{
          "name" = "loki-gateway"
          "port" = 80
        }]
      }]
    }
  }
  depends_on = [helm_release.loki]
}
