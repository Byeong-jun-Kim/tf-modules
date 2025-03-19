resource "kubernetes_namespace" "observability" {
  count = var.in_cluster_setting ? 1 : 0
  metadata {
    name = "observability"
    labels = {
      "istio-injection" = "disabled"
    }
  }
  depends_on = [module.eks_cluster]
}

resource "helm_release" "loki" {
  count      = var.in_cluster_setting ? 1 : 0
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.helm_version_loki
  namespace  = kubernetes_namespace.observability[0].metadata[0].name

  values = [
    <<EOF
loki:
  storage:
    type: s3
    s3:
      region: ${var.region}
    bucketNames:
      chunks: ${module.log_bucket[0].s3_bucket_id}
      ruler: ${module.log_bucket[0].s3_bucket_id}
      admin: ${module.log_bucket[0].s3_bucket_id}
  compactor:
    retention_enabled: true
    delete_request_store: s3
  limits_config:
    retention_period: ${var.loki_retention}
  schemaConfig:
    configs:
    - from: 2024-04-01
      index:
        prefix: index_
        period: 24h
      object_store: s3
      schema: v13
      store: tsdb
monitoring:
  dashboards:
    enabled: false
  rules:
    enabled: false
  serviceMonitor:
    enabled: false
lokiCanary:
  enabled: false
test:
  enabled: false
EOF
  ]
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com\\/role-arn"
    value = module.loki_irsa_role[0].iam_role_arn
  }
  set {
    name  = "deploymentMode"
    value = var.loki_mode
  }
  set {
    name  = "singleBinary.replicas"
    value = var.loki_mode == "SingleBinary" ? var.loki_replicas : 0
  }
  set {
    name  = "read.replicas"
    value = var.loki_mode == "SingleBinary" ? 0 : var.loki_replicas
  }
  set {
    name  = "write.replicas"
    value = var.loki_mode == "SingleBinary" ? 0 : var.loki_replicas
  }
  set {
    name  = "backend.replicas"
    value = var.loki_mode == "SingleBinary" ? 0 : var.loki_replicas
  }
  set {
    name  = "chunksCache.enabled"
    value = "false"
  }
  set {
    name  = "resultsCache.enabled"
    value = "false"
  }
  set {
    name  = "loki.auth_enabled"
    value = "false"
  }
}

resource "helm_release" "fluent_bit" {
  count      = var.in_cluster_setting ? 1 : 0
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  version    = var.helm_version_fluent_bit
  namespace  = kubernetes_namespace.observability[0].metadata[0].name
  set {
    name  = "config.inputs"
    value = <<EOF
[INPUT]
    Name             tail
    Path             /var/log/containers/*.log
    multiline.parser docker\, cri
    Tag              kube.*
    Mem_Buf_Limit    5MB
    Skip_Long_Lines  On
EOF
  }
  set {
    name  = "config.filters"
    value = <<EOF
[FILTER]
    Name        kubernetes
    Match       kube.*
    Merge_Log   On
    Keep_Log    Off
    Labels      Off
    Annotations Off
[FILTER]
    Name  rewrite_tag
    Match kube.*
    Rule  $kubernetes['container_name'] ^(istio-proxy)$ delete.$1 false
${var.fluent_bit_filters}
EOF
  }
  set {
    name  = "config.outputs"
    value = <<EOF
[OUTPUT]
    Name   loki
    Match  kube.*
    Host   loki-gateway
    Port   80
    Labels namespace_name=$kubernetes['namespace_name']\, container_name=$kubernetes['container_name']
${var.fluent_bit_outputs}
EOF
  }
  depends_on = [helm_release.loki]
}
