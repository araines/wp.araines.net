module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.site_domain}-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["${var.aws_region}a", "${var.aws_region}b"]
  database_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets   = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets  = ["10.0.201.0/24", "10.0.202.0/24"] # to avoid bug: https://github.com/terraform-aws-modules/terraform-aws-vpc/issues/944

  create_database_subnet_group = true
}
