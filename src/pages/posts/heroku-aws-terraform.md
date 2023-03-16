---
title: 'Terraforming a site on Heroku and AWS - Part 1'
date: 'March 12, 2023'
description: 'Set up the infrastructure for a WordPress site hosted on Heroku and AWS'
tags: ["infrastructure", "terraform", "webapp"]
slug: 'heroku-aws-terraform'
layout: "../../layouts/PostLayout.astro"
---

In my day job we mainly build WordPress websites which are hosted on Heroku and use several AWS services. Although the setup isn't overly complicated, it can take a while to manually spin up all of the resources required to host our sites, and doing it manually is prone to human error.

The solution is to provision everything using Terraform which allows us to create our infrastructure as code.

This post will run through the scripts required to set up all of the key resources in this common web application stack. We won't modularise each component at this stage, but focus on the core script first.

If you don't already have Terraform installed, check out the [official docs](https://developer.hashicorp.com/terraform/downloads) to set up on your machine first. You'll also need accounts in both Heroku and AWS.

## Overview of required resources

In this example the site will be hosted on Heroku with a database and storage in AWS. The main resources are:

- **Heroku**
    - Web application
    - Logging using papertrail
    - Redis cache
- **AWS**
    - RDS Aurora database

In a later post this setup will be expanded upon to include S3 for storage, image handling and a Content Delivery Network, as well as caching with CloudFront, but for now we'll keep it simple.

## Writing `main.tf` and setting up providers

Create a `main.tf` file in your project directory. This is where any required providers are defined.

In Terraform, providers are plugins which enable interaction with an API. In this example the required providers are Heroku and AWS.

The `main.tf` file will look like this:

```hcl
terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.58.0"
    }
    heroku = {
      source  = "heroku/heroku"
      version = "4.6.0"
    }
  }
}
```

We've declared a terraform block with a required version, identified that we want to use the AWS and Heroku providers, and requested a specific version of each provider.

When we run the `terraform init` command later, these providers will be downloaded and installed.

## Setting up Heroku resources

With the `main.tf` file ready, we can start to write the code to provision resources. In Heroku we want to set up two apps connected with a pipeline, and some addons to add caching and logging.

This configuration could be written directly into the `main.tf` file, but to keep it clean we'll split it up into a new file for each provider.

Create `heroku.tf`
