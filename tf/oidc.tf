# OpenID Connect for GitHub Actions
module "github-oidc" {
  source  = "terraform-module/github-oidc-provider/aws"
  version = "~> 1"

  create_oidc_provider = true
  create_oidc_role     = true
  role_name            = "${var.site_name}-github-oidc"
  role_description     = "Role assumed by the ${var.site_domain} GitHub OIDC provider"

  repositories              = ["araines/wp.araines.net"]
  oidc_role_attach_policies = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"]
}
