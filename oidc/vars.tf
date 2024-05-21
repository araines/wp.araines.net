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
