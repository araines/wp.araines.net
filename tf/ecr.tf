# Elastic Container Registry

resource "aws_ecr_repository" "serverless_wordpress" {
  name = "${var.site_name}-serverless-wordpress"
  image_scanning_configuration {
    scan_on_push = true
  }
}
