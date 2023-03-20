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

If you don't already have Terraform installed, check out the [official docs](https://developer.hashicorp.com/terraform/downloads) to set up on your machine first. You'll also need accounts in both Heroku and AWS. It's also worth noting that this isn't an absolute beginners Terraform tutorial. There are quite a few resources to create here, so knowing your way around Terraform might help.

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

With the `main.tf` file ready, we can start to write the code to provision resources. In Heroku we want to set up an app and some addons to add caching and logging.

This configuration could be written directly into the `main.tf` file, but to keep it clean we'll split it up into a new file for each provider.

Create a new file `heroku.tf` in the same directory as `main.tf`. When Terraform commands are run all .tf files are included, so it is fine to split resources across multiple files if you prefer to organise your code this way.

### Add the app

The first thing to add is the application itself. Below is code to create a staging site. This code can be duplicated to create your production app, except anywhere that it says "**staging**" would be changed to "**production**":

```hcl
resource "heroku_app" "staging" {
  name   = "${var.app_name}-test"
  region = var.app_region
  buildpacks = [
    "heroku/nodejs",
    "heroku/php",
  ]
  config_vars = {
    AWS_ACCESS_KEY_ID     = ""
    AWS_SECRET_ACCESS_KEY = ""
    DB_URL                = ""
    WP_HOME               = ""
    WP_POST_REVISIONS     = 5
    WP_SITEURL            = ""
  }
}
```

> **Important note:**
>
> 1. `config_vars` is used to set environment variables in your Heroku app. In this example there are a few variables which might be useful in a WordPress site, but these can be customised.
> 2. There are two variables used here `app_name` and `app_region`. We'll come back to these later in the article.

The code above will create a Heroku application:

1. `name` is the name of your application
2. `region` is the region where your application will exist. If you plan on having AWS resources in Europe, then your Heroku app should also exist in Europe to reduce latency between your app and your database.
3. `buildpacks` are the builds that we want to use when we deploy an app. Since this infrastructure is designed for a WordPress website we'll use PHP and NodeJS for compiling assets.
4. `config_vars` is where we can add environment variables which we'll use in our application.

### Including Add-ons

[Redis](https://devcenter.heroku.com/articles/heroku-redis) and [Papertrail](https://elements.heroku.com/addons/papertrail) will be included for caching and logging in the site. Read more about these add-ons in the Heroku documentation.

```hcl
# Create redis add-on and configure the app to use it
resource "heroku_addon" "redis-staging" {
  app   = heroku_app.staging.name
  plan  = "heroku-redis:mini"
  config = {
    maxmemory_policy = "allkeys-lru"
  }
}

# Create papertrail add-on and configure the app to use it
resource "heroku_addon" "papertrail-staging" {
  app   = heroku_app.staging.name
  plan  = "papertrail:choklad"
}
```

## Setting up the RDS Aurora database

The database for the WordPress application will be hosted in AWS Relation Database Service (RDS), and it is an Aurora MySQL database.

The following code will provision an Aurora cluster and a database instance. You may want to create a new `aws.tf` file to write your AWS resources:

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

resource "aws_rds_cluster" "staging-cluster" {
  cluster_identifier      = "${var.app_name}-staging-cluster"
  engine                  = "aurora-mysql"
  engine_version          = "5.7.mysql_aurora.2.09.2"
  availability_zones      = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  database_name           = "${var.app_name}Test"
  master_username         = var.database_username
  master_password         = var.database_password
  backup_retention_period = 5
  preferred_backup_window = "07:00-09:00"
  skip_final_snapshot     = true
  vpc_security_group_ids  = [aws_security_group.sg.id]
}

resource "aws_rds_cluster_instance" "staging-instance" {
  identifier          = "${var.app_name}test"
  cluster_identifier  = aws_rds_cluster.staging-cluster.id
  instance_class      = "db.t2.small"
  engine              = aws_rds_cluster.staging-cluster.engine
  engine_version      = aws_rds_cluster.staging-cluster.engine_version
  publicly_accessible = true
}
```

> **Important note:**
>
> 1. As in the Heroku application, we reference some variables here. These are set in a `variables.tf` file which will be explained later.
> 2. The `aws_rds_cluster_instance` resource referenecs the staging cluster, `aws_rds_cluster`. Since we won't know the values of these things until the `aws_rds_cluster` has been created, Terraform will automatically order the creation of resources depending on what is required. So `aws_rds_cluster` will be provisioned first, then `aws_rds_cluster_instance` after.
> 3.There is a reference to `aws_security_group.sg.id`. In order to make the database public we need specific rules for our inbound traffic. We'll create the security group next.
> 4. Read more about [provisioning RDS clusters](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster) and [RDS instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/rds_cluster_instance)

## Create the security group

To make the database publicly accessible we need to set our CIDR blocks to `0.0.0.0/0` which allows inbound HTTPS access from all IPv4 addresses. Add the following code to your `aws.tf` file to provision the required security groups.

```hcl
resource "aws_security_group" "sg" {
  name        = "sg"
  description = "Web Security Group for RDS"
}

# Rules for inbound traffic
resource "aws_security_group_rule" "inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.sg.id

  from_port        = 0
  to_port          = 0
  protocol         = "-1"
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

# Rules for outbound traffic
resource "aws_security_group_rule" "outbound" {
  type              = "egress"
  security_group_id = aws_security_group.sg.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

In the above we create a security group named `sg`. We then create security group rules for inbound and outbound traffic, and associate them with our newly created security group by referencing its ID: `security_group_id = aws_security_group.sg.id`

## Terraform variables

In the code above we referenced a handful of variables. To make sure that these work we need to set up a variables file, otherwise there will be errors when we try to run our Terraform scripts. To do this create a file in the same directory as your other `.tf` files, called `variables.tf`. The basic syntax of a variable is:

```hcl
variable "variable_name" {
  description = "A description of what the variable is for"
}
```

There are various arguements available for your variable declarations, which you can read about in the [Terraform variables documentation](https://developer.hashicorp.com/terraform/language/values/variables#arguments). The file in this example will look like:

```hcl
variable "app_name" {
  description = "Name of the Heroku app provisioned (lowercase letters and hyphens only)"
  validation {
    # regex(...) will fail if it cannot find a match
    # lowercase letters and hyphens only
    condition     = can(regex("^[a-z]+(-[a-z]+)*$", var.app_name))
    error_message = "The app name may only contain lowercase letters and hyphens."
  }
}
variable "app_region" {
  description = "Region the app is provisioned in"
  default     = "Europe"
}

variable "database_username" {
  description = "Database username"
}
variable "database_password" {
  description = "Database password (Min length 8 characters)"
  validation {
    # regex(...) will fail if it cannot find a match
    # Minimum 8 characters including upper/lower case letters, numbers and punctuation [!"#$%&'()*+,\-./:;<=>?@[\]^_`{|}~]
    condition     = can(regex("^[a-zA-Z0-9[:punct:]]{8,}$", var.database_password))
    error_message = "The database password must contain at least 8 characters."
  }
}
```

There are also various ways to set the values for your variables. If you do nothing, you will be prompted in the command line to fill out any variables you have created and referenced in your script. But in this example we'll create a file called `terraform.tfvars`. When you run your script Terraform will check if this file exists, and if it does it will use the values provided.

```hcl
app_name = "app-name-here"
app_region = "region can be added here if you don't want to use the default"
database_username = "username-here"
database_password = "password-here"
```
