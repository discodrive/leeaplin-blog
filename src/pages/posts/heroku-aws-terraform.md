---
title: 'Terraforming a site on Heroku and AWS'
date: 'February 28, 2023'
description: 'Set up the infrastructure for a WordPress site hosted on Heroku and AWS'
tags: ["infrastructure", "terraform", "webapp"]
slug: 'heroku-aws-terraform'
layout: "../../layouts/PostLayout.astro"
---

In my day job we mainly build WordPress websites which are hosted on Heroku and use several AWS services. Although the setup isn't overly complicated, it can take a while to manually spin up all of the resources required to host our sites, and doing it manually is prone to human error.

The solution is to provision everything using Terraform which allows us to create our infrastructure as code. 

This post will run through the scripts required to set up all of the key resources in this common web application stack.

## Overview of required resources

In this example the site will be hosted on Heroku with a database and storage in AWS. The main resources are:

- Heroku
    - Web application
    - Logging using papertrail
    - Redis cache
- AWS
    - RDS Aurora database
    - S3 storage
