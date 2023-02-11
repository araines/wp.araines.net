# Create the S3 bucket & Cloudfront distribution for the static website
locals {
  s3_origin_id = "${var.site_domain}-S3Origin"
}

resource "aws_s3_bucket" "website" {
  bucket        = var.site_domain
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.bucket

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_cloudfront_origin_access_identity" "website" {
  comment = "${var.site_name} origin access identity for S3"
}

resource "random_password" "s3_referer_header" {
  length  = 40
  special = false
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_domain
    origin_id   = local.s3_origin_id

    custom_header {
      name  = "Referer"
      value = random_password.s3_referer_header.result
    }
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2"
      ]
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.site_domain} distribution"
  default_root_object = "index.html"

  aliases = [var.site_domain]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    compress         = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 600
    max_ttl                = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    minimum_protocol_version = "TLSv1.2_2021"
    acm_certificate_arn      = aws_acm_certificate.website.arn
    ssl_support_method       = "sni-only"
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.cloudfront_s3_access.json
}

data "aws_iam_policy_document" "cloudfront_s3_access" {
  statement {
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${aws_s3_bucket.website.arn}/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:Referer"
      values = [
        random_password.s3_referer_header.result
      ]
    }
  }
}

