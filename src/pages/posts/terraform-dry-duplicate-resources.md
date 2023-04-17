---
title: 'Setting up multiples of the same resource with Terraform'
date: 'April 17, 2023'
description: 'While writing Terraform scripts, it is often required to set up multiples of the same resource. Read how to do this while still keeping your code DRY (Dont Repeat Yourself).'
tags: ["aws", "terraform"]
slug: 'terraform-dry-duplicate-resources'
layout: "../../layouts/PostLayout.astro"
---

## Keeping Terraform DRY

Terraform scripts can become quite long and involved, especially when you're builing out larger projects. I recently worked on a project which needed multiple subnets. Each subnet needed a different `cidr_block`, but otherwise they were pretty much the same.

Rather than duplicating the same code block 6 times to set up each of the subnets I opted for keeping the code DRY and looping over an array to get each unique `cidr_block`. This keeps the code clean and uncluttered, and the subnets are all configured in once place, in the variables file (`terraform.tfvars`).
