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

  site_name             = "blog"
  site_domain           = "araines.net"
  hosted_zone_id        = "Z1BMFFD43RYRYX"
  wordpress_admin_email = "andrew.raines@gmail.com"
  wordpress_admin_user  = "araines"
  wordpress_site_name   = "Andy Raines"
}
