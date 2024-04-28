variable "launch" {
  description = "Spin up/down WordPress (1 to spin up)"
  type        = number
  default     = 0
}

variable "repository" {
  description = "The GitHub repository name for tagging purposes"
  type        = string
}

variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "site_name" {
  description = "The name of the site for AWS resource purposes (alphanumeric)"
  type        = string
}

variable "site_domain" {
  description = "The domain of the website"
  type        = string
}

variable "hosted_zone_id" {
  description = "The hosted zone id to set up the DNS records within"
  type        = string
}

variable "wordpress_admin_email" {
  description = "The WordPress admin user email address"
  type        = string
}

variable "wordpress_admin_user" {
  description = "The WordPress admin user username"
  type        = string
}

variable "wordpress_admin_password" {
  description = "The WordPress admin user initial password"
  type        = string
  default     = "changeme"
}

variable "wordpress_site_name" {
  description = "The name of the site for WordPress"
  type        = string
}
