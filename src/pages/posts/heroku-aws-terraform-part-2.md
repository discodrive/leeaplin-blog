---
title: 'Terraforming a WordPress site on Heroku and AWS - Part 2'
date: 'March 26, 2023'
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
