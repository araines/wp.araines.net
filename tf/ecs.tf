# ECS for running the dynamic WordPress site

resource "aws_efs_file_system" "wordpress" {
  encrypted = true
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
}

resource "aws_efs_file_system" "database" {
  encrypted = true
  lifecycle_policy {
    transition_to_ia = "AFTER_7_DAYS"
  }
}

data "aws_iam_policy_document" "wordpress_bucket_access" {
  statement {
    actions   = ["s3:ListBucket"]
    effect    = "Allow"
    resources = [aws_s3_bucket.website.arn]
  }
  statement {
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.website.arn}/*"]
  }
  statement {
    actions   = ["ec2:DescribeNetworkInterfaces"]
    effect    = "Allow"
    resources = ["*"]
  }
  statement {
    actions   = ["route53:ChangeResourceRecordSets"]
    effect    = "Allow"
    resources = ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"]
  }
}

resource "aws_iam_policy" "wordpress_bucket_access" {
  name        = "${var.site_name}_WordPressBucketAccess"
  description = "Policy allowing WordPress access to static site bucket"
  policy      = data.aws_iam_policy_document.wordpress_bucket_access.json
}

resource "aws_iam_role_policy_attachment" "wordpress_bucket_access" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = aws_iam_policy.wordpress_bucket_access.arn
}

data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "ecs.amazonaws.com",
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "wordpress_task" {
  name               = "${var.site_name}_WordPressTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "wordpress_role_attachment_ecs" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "wordpress_role_attachment_cloudwatch" {
  role       = aws_iam_role.wordpress_task.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_efs_access_point" "wordpress_efs" {
  file_system_id = aws_efs_file_system.wordpress.id
}

resource "aws_efs_access_point" "database_efs" {
  file_system_id = aws_efs_file_system.database.id
}

resource "aws_security_group" "efs_security_group" {
  name        = "${var.site_name}_efs_sg"
  description = "Security Group for Wordpress"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "efs_ingress" {
  description              = "Ingress for EFS mount for WordPress"
  security_group_id        = aws_security_group.efs_security_group.id
  source_security_group_id = aws_security_group.wordpress_security_group.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "TCP"
}

resource "aws_efs_mount_target" "wordpress_efs" {
  count           = length(module.vpc.public_subnets)
  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = module.vpc.public_subnets[count.index]
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_efs_mount_target" "database_efs" {
  count           = length(module.vpc.public_subnets)
  file_system_id  = aws_efs_file_system.database.id
  subnet_id       = module.vpc.public_subnets[count.index]
  security_groups = [aws_security_group.efs_security_group.id]
}

resource "aws_cloudwatch_log_group" "wordpress_container" {
  name              = "/aws/ecs/${var.site_name}-wordpress"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "database_container" {
  name              = "/aws/ecs/${var.site_name}-database"
  retention_in_days = 7
}

resource "random_password" "database" {
  length           = 16
  special          = true
  override_special = "!#%&*()-_=+[]<>"
}

resource "random_password" "database_root" {
  length           = 16
  special          = true
  override_special = "!#%&*()-_=+[]<>"
}

resource "aws_ecs_task_definition" "wordpress" {
  family = "${var.site_name}_wordpress"
  container_definitions = templatefile("${path.module}/wordpress-task.tftpl", {
    db_host          = "127.0.0.1"
    db_user          = "wordpress"
    db_password      = random_password.database.result
    db_name          = "wordpress"
    db_root_password = random_password.database_root.result

    wp_dest   = "https://${var.site_domain}"
    wp_region = var.aws_region
    wp_bucket = aws_s3_bucket.website.id

    logs_wp = aws_cloudwatch_log_group.wordpress_container.name
    logs_db = aws_cloudwatch_log_group.database_container.name

    efs_wp = "${var.site_name}_wordpress"
    efs_db = "${var.site_name}_database"

    image_wp = "${aws_ecr_repository.serverless_wordpress.repository_url}:latest",
    image_db = "mysql"

    container_dns            = "wordpress.${var.site_domain}",
    container_dns_zone       = var.hosted_zone_id,
    container_cpu            = 1024,
    container_memory         = 2048,
    wordpress_admin_user     = var.wordpress_admin_user
    wordpress_admin_password = var.wordpress_admin_password
    wordpress_admin_email    = var.wordpress_admin_email
    wordpress_site_name      = var.wordpress_site_name
    site_name                = var.site_name
  })

  cpu                      = 2048
  memory                   = 4096
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.wordpress_task.arn
  task_role_arn            = aws_iam_role.wordpress_task.arn

  volume {
    name = "${var.site_name}_wordpress"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.wordpress.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.wordpress_efs.id
      }
    }
  }
  volume {
    name = "${var.site_name}_database"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.database.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.database_efs.id
      }
    }
  }
  tags = {
    "Name" = "${var.site_name}_WordpressECS"
  }
  depends_on = [
    aws_efs_file_system.wordpress,
    aws_efs_file_system.database
  ]
}

resource "aws_security_group" "wordpress_security_group" {
  name        = "${var.site_name}_wordpress_sg"
  description = "security group for wordpress"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "wordpress_sg_ingress_80" {
  description       = "Allow ingress from world to Wordpress container"
  security_group_id = aws_security_group.wordpress_security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
}

resource "aws_security_group_rule" "wordpress_sg_egress_2049" {
  description              = "Egress to EFS mount from Wordpress container"
  security_group_id        = aws_security_group.wordpress_security_group.id
  source_security_group_id = aws_security_group.efs_security_group.id
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "TCP"
}

resource "aws_security_group_rule" "wordpress_sg_egress_80" {
  description       = "Egress from Wordpress container to world on HTTP"
  security_group_id = aws_security_group.wordpress_security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
}

resource "aws_security_group_rule" "wordpress_sg_egress_443" {
  description       = "Egress from Wordpress container to world on HTTPS"
  security_group_id = aws_security_group.wordpress_security_group.id
  cidr_blocks       = ["0.0.0.0/0"]
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
}

resource "aws_ecs_service" "wordpress_service" {
  name            = "${var.site_name}_wordpress"
  task_definition = "${aws_ecs_task_definition.wordpress.family}:${aws_ecs_task_definition.wordpress.revision}"
  cluster         = aws_ecs_cluster.wordpress_cluster.arn
  desired_count   = var.launch

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = "100"
    base              = "1"
  }
  propagate_tags = "SERVICE"
  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.wordpress_security_group.id]
    assign_public_ip = true
  }
}

resource "aws_ecs_cluster" "wordpress_cluster" {
  name = "${var.site_name}_wordpress"
}

resource "aws_ecs_cluster_capacity_providers" "wordpress_cluster" {
  cluster_name       = aws_ecs_cluster.wordpress_cluster.name
  capacity_providers = ["FARGATE_SPOT"]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}
