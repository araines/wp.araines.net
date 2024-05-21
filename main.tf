terraform {
  required_version = "~> 1.3"

  backend "s3" {
    bucket = "araines-tfstate"
    key    = "araines.net/terraform.tfstate"
    region = "eu-west-1"
  }
}

module "wordpress" {
  source = "./tf"

  repository            = "wp.araines.net"
  site_name             = "blog"
  site_domain           = "araines.net"
  hosted_zone_id        = "Z1BMFFD43RYRYX"
  wordpress_admin_email = "andrew.raines@gmail.com"
  wordpress_admin_user  = "araines"
  wordpress_site_name   = "Andy Raines"

  launch = var.launch
}

module "oidc" {
  source = "./oidc"

  repository  = "wp.araines.net"
  site_name   = "blog"
  site_domain = "araines.net"
}

#module "static-wordpress" {
#  source = "git@github.com:araines/aws-static-wordpress.git"
#
#  repository            = "wp.araines.net"
#  site_name             = "blog"
#  site_domain           = "araines.net"
#  hosted_zone_id        = "Z1BMFFD43RYRYX"
#  wordpress_admin_email = "andrew.raines@gmail.com"
#  wordpress_admin_user  = "araines"
#  wordpress_site_name   = "Andy Raines"
#
#  launch = var.launch
#}

#moved {
#  from = module.wordpress.module.vpc
#  to   = module.static-wordpress.module.vpc
#}

variable "launch" {
  description = "Spin up/down WordPress (1 to spin up)"
  type        = number
  default     = 0
}
