output "oidc_provider_arn" {
  value = module.eks_cluster.oidc_provider_arn
}

output "eks_node_groups_role_arns" {
  value = module.node_groups_iam_role.iam_role_arn
}

output "s3_csi_irsa_role_arn" {
  value = module.s3_csi_irsa_role.iam_role_arn
}

output "cluster_name" {
  value = module.eks_cluster.cluster_name
}

output "load_balancer_name" {
  value = local.load_balancer_name
}
output "load_balancer_vpc_origin_id" {
  value = aws_cloudfront_vpc_origin.gateway[*].id
}
