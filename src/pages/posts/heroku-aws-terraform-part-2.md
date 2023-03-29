---
title: 'Terraforming a WordPress site on Heroku and AWS - Part 2'
date: 'March 29, 2023'
description: 'Expand upon the basic resources from part 1, adding some storage with S3 and caching with CloudFront'
tags: ["infrastructure", "terraform", "cloudfront", "s3", "wordpress"]
slug: 'heroku-aws-terraform-part-2'
layout: "../../layouts/PostLayout.astro"
---

In [Terraforming a WordPress site on Heroku and AWS - Part 1](/posts/heroku-aws-terraform) we set up the basic resources required for running a WordPress website hosted on Heroku and AWS. These scripts can now be expanded to include some other useful resources.

The [scripts from the previous post can be found on GitHub](https://github.com/discodrive/blog-post-terraform-example). To recap, we set up:

 - A single Heroku app using the PHP buildpack to host a WordPress site
 - Heroku add-ons for logging and Redis caching
 - An RDS Aurora MySQL database
 - The Security Group required to give suitable access to the database

The new additions we'll cover in this post are:

- An S3 bucket for storing WordPress uploads and website assets
- A CloudFront distribution for caching web pages, including caching policies

## Provision an S3 bucket

Since a Heroku app is ephemeral, it isn't possible to store any WordPress uploads on Heroku itself. This can be resolved by offloading media directly to an AWS S3 bucket. [Humanmade have a good plugin which handles the actual offloading](https://github.com/humanmade/S3-Uploads) of the media, so we'll just set up the bucket.

In the `aws.tf` file, add an `aws_s3_bucket` resource. The code for this is very simple:

```hcl
resource "aws_s3_bucket" "bucket" {
  bucket = "${var.app_name}"
  acl    = "public"

  tags = {
    Name = "WordPress media bucket"
  }
}
```

We've requested an AWS S3 bucket with the same name as our application. Ideally access to the bucket should be restricted, but in the interest of keeping this script simple, for now it is set to public. This will allow WordPress to upload to it freely, as well as retrieve the media when it is requested on web pages.

## Setting up CloudFront

Now that the simple part is done, lets move onto setting up CloudFront.

CloudFront is used for caching web pages on the WordPress site, which is quite important as WordPress has a bit of room for improvement when it comes to performance. It requires some specific settings to allow WordPress to function correctly, and you can read about these settings in detail in [this old (but still relevant) AWS blog post](https://aws.amazon.com/blogs/startups/how-to-accelerate-your-wordpress-site-with-amazon-cloudfront/).

CloudFront has a few things to configure:

- A default cache policy
- An admin cache policy
- An origin request policy
- A CloudFront distribution

Since there is quite a lot of config for CloudFront, you may want to create a new file called `cloudfront.tf`.

### Default cache policy

```hcl
resource "aws_cloudfront_cache_policy" "default_cache_policy" {
  name        = "Wordpress-Main-Distribution"
  comment     = "Caching policy for the public website"
  default_ttl = 300
  max_ttl     = 300
  min_ttl     = 300
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "whitelist"
      cookies {
        items = [
          "comment_author_*",
          "comment_author_email_*",
          "comment_author_url_*",
          "wordpress_*",
          "wp-postpass_*",
          "wordpress_logged_in_*",
          "wordpress_cookie_login",
          "wp_settings-*"
        ]
      }
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "Origin",
          "Options",
          "Host"
        ]
      }
    }
    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings {
        items = [
          "s"
        ]
      }
    }
  }
}
```

This code will provision the default cache policy which can be used in the distribution. For WordPress we need to set up two cache policies, one for the public side of the website, and another policy for the admin area.

The cache time is set to `300` seconds (5 minutes) which allows the cache to invalidate quickly enough to show updates soon enough after they have been published to the site.

The `cookies_config` section declares which cookies will be considered when building the cache key, and the ones added here are all required for WordPress to work correctly. The same applies for the `headers_config`; these headers are all necessary for correct functionality.

Finally we set a list of allowed query strings. This list will vary depending on the functionality of your site, so remember to add to the allowed list each time you use a query string in your code. By default we've added `s` which is used for search queries in a WordPress site.

### Admin cache policy

```hcl
resource "aws_cloudfront_cache_policy" "admin_cache_policy" {
  name        = "WordPress-Admin-Policy"
  comment     = "Caching policy for the admin section of the website"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1
  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "whitelist"
      cookies {
        items = [
          "comment_author_*",
          "comment_author_email_*",
          "comment_author_url_*",
          "wordpress_*",
          "wordpress_logged_in_*",
          "wordpress_cookie_login",
          "wp_settings-*"
        ]
      }
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "Origin",
          "Host"
        ]
      }
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}
```

The admin cache policy looks similar to the default one with a couple of changes.

1. The cache times have been changed
2. All query strings are now accepted

### Origin request policy

```hcl
resource "aws_cloudfront_origin_request_policy" "default_origin_request_policy" {
  name    = "HeaderWhitelistAllCookiesAndQueryStrings"
  comment = ""
  cookies_config {
    cookie_behavior = "all"
  }
  headers_config {
    header_behavior = "whitelist"
    headers {
      items = [
        "Origin",
        "Options",
        "Host",
        "Referer"
      ]
    }
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}
```

### CloudFront Distribution

When setting up the distribution we'll reference the policy resources that we previously set up. When we run `terraform apply` it will be smart enough to know that the distribution requires these resources, so they'll be created first.

```hcl
resource "aws_cloudfront_distribution" "staging_distribution" {
  origin {
    domain_name = var.staging_domain_name
    origin_id   = var.staging_origin_id

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Staging standard distribution for caching web pages"

  aliases = []

  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD", "OPTIONS"]
    target_origin_id         = var.staging_origin_id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.default_origin_request_policy.id
    cache_policy_id          = aws_cloudfront_cache_policy.default_cache_policy.id

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = false
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern             = "/wp-admin/*"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = var.staging_origin_id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.default_origin_request_policy.id
    cache_policy_id          = aws_cloudfront_cache_policy.admin_cache_policy.id

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = false
    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

We've set up two cache behaviours, a default behaviour which will be applied to all pages, and an ordered cache behaviour which will be applied to any `/wp-admin/*` paths. You can see that in both behaviours we reference the relevant cache policy in `cache_policy_id`.

We also reference a couple of new variables which we'll need to add to the `variables.tf` file, `staging_domain_name` and `staging_origin_id`. Add the following to your `variables.tf` file to set these variables up:

```hcl
variable "staging_domain_name" {
  type = string
  description = "Domain name of the staging app. e.g. test.herokuapp.com"
}

variable "staging_origin_id" {
  type = string
  description = "Identifier for the staging origin. e.g. app-name-test"
}
```

One other thing of note in the `aws_cloudfront_distribution` above is the `viewer_certificate`. In order for CloudFront to work with your application, you'll need to set up a certificate in Amazon Certificate Manager. The reason that this is left to do manually rather than in this script, is because you need to verify you domain via DNS to validate the certificate.

If you are using Route 53, then this can be automated in a Terraform script, but if your DNS is handled anywhere else it is harder to automate this stage, so we'll handle it manually.

### Certificate

In your AWS account navigate to ACM. Ensure that you're in region `us-east-1` and add a new certificate for the domain of your website. You'll be able to add this domain name into your distribution config once the certificate is provisioned, and at that point you'll need to add a CNAME record for your domain root, with the CloudFront domain as the value.

## Summary

In this post we expanded upon the resources we created in [part 1](/posts/heroku-aws-terraform) by adding an S3 bucket for storage and a CloudFront distribution to improve website performance. The scripts that were added in this post can be found in the part 2 directory on the [Terraform blog post repo in my GitHub account](https://github.com/discodrive/blog-post-terraform-example/tree/main/part-2).

Next time we'll finish off the stack for this website architecture by adding a pipeline into Heroku so that we can have both a staging application and a deployment application, and we'll also provision some basic website uptime monitoring using Status Cake.
