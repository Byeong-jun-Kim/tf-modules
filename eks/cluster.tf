resource "kubernetes_storage_class_v1" "gp3" {
  count = var.in_cluster_setting ? 1 : 0
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    type = "gp3"
  }
  depends_on = [module.eks_cluster]
}

resource "kubernetes_storage_class_v1" "gp3_snapshot" {
  count = var.in_cluster_setting ? 1 : 0
  metadata {
    name = "gp3-snapshot"
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  parameters = {
    type             = "gp3"
    tagSpecification = "Snapshot=true"
  }
  depends_on = [module.eks_cluster]
}

resource "kubernetes_annotations" "gp2_not_default" {
  count       = var.in_cluster_setting ? 1 : 0
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
  force      = true
  depends_on = [module.eks_cluster]
}

resource "helm_release" "metrics_server" {
  count      = var.in_cluster_setting ? 1 : 0
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.helm_version_metrics_server
  namespace  = "kube-system"
  depends_on = [module.eks_cluster]
}

resource "helm_release" "aws_load_balancer_controller" {
  count      = var.in_cluster_setting ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.helm_version_aws_load_balancer_controller
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = module.eks_cluster.cluster_name
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com\\/role-arn"
    value = module.load_balancer_controller_irsa_role[0].iam_role_arn
  }
  depends_on = [module.eks_cluster, module.load_balancer_controller_irsa_role]
}

resource "helm_release" "external_dns" {
  count      = var.in_cluster_setting ? 1 : 0
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.helm_version_external_dns
  namespace  = "kube-system"
  set {
    name  = "provider"
    value = "aws"
  }
  set_list {
    name  = "sources"
    value = ["service", "ingress"]
  }
  set {
    name  = "txtPrefix"
    value = "external-dns-"
  }
  set {
    name  = "policy"
    value = "sync"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com\\/role-arn"
    value = module.external_dns_irsa_role[0].iam_role_arn
  }
  depends_on = [module.eks_cluster, module.external_dns_irsa_role]
}

resource "helm_release" "botkube" {
  count            = var.in_cluster_setting ? 1 : 0
  name             = "botkube"
  repository       = "https://charts.botkube.io"
  chart            = "botkube"
  version          = var.helm_version_botkube
  namespace        = "botkube"
  create_namespace = true
  set {
    name  = "settings.clusterName"
    value = module.eks_cluster.cluster_name
  }
  set {
    name  = "communications.default-group.socketSlack.enabled"
    value = "true"
  }
  set {
    name  = "communications.default-group.socketSlack.channels.default.name"
    value = var.botkube_slack_channel
  }
  set {
    name  = "communications.default-group.socketSlack.appToken"
    value = var.botkube_slack_app_token
  }
  set {
    name  = "communications.default-group.socketSlack.botToken"
    value = var.botkube_slack_bot_token
  }
  set {
    name  = "executors.k8s-default-tools.botkube/kubectl.enabled"
    value = "false"
  }
  set {
    name  = "executors.k8s-default-tools.botkube/helm.enabled"
    value = "false"
  }
  set_list {
    name  = "communications.default-group.socketSlack.channels.default.bindings.sources"
    value = ["k8s-err-events", "k8s-recommendation-events", "k8s-create-events"]
  }
  depends_on = [module.eks_cluster]
}

resource "helm_release" "argo_cd" {
  count            = var.in_cluster_setting ? 1 : 0
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.helm_version_argo_cd
  namespace        = "argo-cd"
  create_namespace = true
  set {
    name  = "dex.enabled"
    value = "false"
  }
  set {
    name  = "notifications.enabled"
    value = "false"
  }
  set {
    name  = "redisSecretInit.podLabels.sidecar\\.istio\\.io\\/inject"
    value = "false"
    type  = "string"
  }
  depends_on = [module.eks_cluster]
}

resource "helm_release" "istio_base" {
  count            = var.in_cluster_setting ? 1 : 0
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.helm_version_istio
  namespace        = "istio-system"
  create_namespace = true
  set {
    name  = "base.enableCRDTemplates"
    value = "false"
  }
  depends_on = [module.eks_cluster]
}
resource "helm_release" "istiod" {
  count      = var.in_cluster_setting ? 1 : 0
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.helm_version_istio
  namespace  = helm_release.istio_base[0].namespace
  set {
    name  = "sidecarInjectorWebhook.enableNamespacesByDefault"
    value = var.istio_sidecar_enable_default ? "true" : "false"
  }
  set {
    name  = "base.enableIstioConfigCRDs"
    value = "false"
  }
  # TODO
  set {
    name  = "global.proxy.resources.requests.cpu"
    value = "10m"
  }
  set {
    name  = "global.proxy.resources.requests.memory"
    value = "64Mi"
  }
  set {
    name  = "pilot.env.PILOT_ENABLE_ALPHA_GATEWAY_API"
    value = "true"
  }
  depends_on = [helm_release.istio_base]
}
