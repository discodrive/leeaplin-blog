---
title: 'Terraforming a WordPress site on Heroku and AWS - Part 3'
date: 'March 30, 2023'
description: 'Finish off provisioning the infrastructure for a WordPress site hosted on Heroku and AWS by adding a pipeline in Heroku to set up both staging and production environments'
tags: ["infrastructure", "terraform", "heroku", "wordpress"]
slug: 'heroku-aws-terraform-part-3'
layout: "../../layouts/PostLayout.astro"
---

There are some final improvements we can make to the infrastructure for the WordPress site. In the [last post](/posts/heroku-aws-terraform-part-2) we added:

- A CloudFront distribution
- CloudFront caching policies
- An S3 bucket used for storing any media uploaded to the website

This time we'll add a production environment to Heroku and a pipeline connecting the staging and production sites. This setup is common for testing new features before promoting them into a live website, but manually setting up two copies of all of the required resources is a pain, so Terraform can do the heavy lifting for us.

The production site will more or less replicate what we've already set up for the staging site, with only a few config changes. The main addition here will be the pipeline and the pipeline couplings which will connect everything together.

## Set up the production site

As mentioned above, the setup for 
