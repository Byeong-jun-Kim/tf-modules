module "container_registry" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "2.2.1"
  providers = {
    aws = aws.prod
  }
  for_each                          = var.repositories
  repository_name                   = each.key
  repository_read_write_access_arns = var.repository_access_arns
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        selection = {
          tagStatus   = "any",
          countType   = "imageCountMoreThan",
          countNumber = 300
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
