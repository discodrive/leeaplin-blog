---
title: 'Setting up duplicate resources with Terraform'
date: 'April 17, 2023'
description: 'While writing Terraform scripts, it is often required to set up multiples of the same resource with minor differences. Read how to do this while still keeping your code DRY (Dont Repeat Yourself).'
tags: ["aws", "terraform"]
slug: 'terraform-dry-duplicate-resources'
layout: "../../layouts/PostLayout.astro"
---

Terraform scripts can become quite long and involved, especially when you're builing out larger projects. I recently worked on a project which needed multiple subnets. Each subnet needed a different `cidr_block`, but otherwise they were pretty much the same.

## Keeping Terraform DRY

Rather than duplicating the same code block 6 times to set up each of the subnets I opted for keeping the code DRY and looping over a list of objects to get each unique `cidr_block`. This keeps the code clean and uncluttered, and the subnets are all configured in once place, in the variables file (`terraform.tfvars`).

## How to do it

We'll need three pieces of code for this method to work:
1. A `variable` to state which unique values can be defined for each item we create
2. Actual data in the `terraform.tfvars` file
3. A resource block which loops over the data from the `terraform.tfvars` file to create the multiple resources

### variables.tf

The first thing to do is create a variable which can be used to set up the unique values for each resource. In the example of subnets in a VPC, the main unique value to each subet is the `cidr_block`. This is simply a string value representing an IP address or IP range.

In your `variables.tf` file, create a variable with the type of `list` and inside that list, define an object. Within this object is where we will specify the unique elements:

```shell
variable "subnets" {
    type = list(object({
        cidr_block = string
        name_tag = string
    }))
}
```
*variables.tf*

### terraform.tfvars

Once this is done, we can input this data via the `terraform.tfvars` file. Here we're adding the data for 4 subnets with different `cidr_blocks` and a tag to easily distinguish between each subnet once the resource is provisioned.

```shell
subnets = [
    {
        cidr_block = "10.0.2.0/24"
        name_tag = "Private Subnet 1 - App Tier"
    },
    {
        cidr_block = "10.0.3.0/24"
        name_tag = "Private Subnet 2 - App Tier"
    },
    {
        cidr_block = "10.0.4.0/24"
        name_tag = "Private Subnet 3 - DB Tier"
    },
    {
        cidr_block = "10.0.5.0/24"
        name_tag = "Private Subnet 4 - DB Tier"
    }
]
```
*terraform.tfvars*

### Write the resource block

The last step is to write the actual resource block for the subnets. To loop over the list and create multiple resources, we can use the `count` meta-argument. `count` requires that we input an integer to represent the number of objects we want to create, so you would typically write something like `count = 2` to create 2 of a particular resource.

We can provide this integer by finding out the length of our array, and this is done using the `length()` function, which returns the length of a list, map or string.

```shell
resource "aws_subnet" "subnets" {
    count = length(var.subnets)
    vpc_id = aws_vpc.main.id
    cidr_block = var.subnets[count.index].cidr_block

    tags = {
        Name = var.subnets[count.index].name_tag
    }
}
```

In the above example:

1. We specify the number of copies of the resource in the `count` meta-argument by finding the length of the `subnets` list. In this case it is 4, because we have 4 unique objects.
2. Each time we loop over the list the `count.index` increments by one, and the `cidr_block` is determined by getting the `cidr_block` from each object.
3. We use the same approach to set the `Name` tag for each resource, extracting the value from the `name_tag` of each object.

## Summary

This example will provision 4 subnets, but the same technique can be applied to creating multiple copies of any resource, and you can further expand upon this by adding more data into the objects in your variable. The resulting Terraform code is a lot smaller and easier to read - rather than 30+ lines of code to provision these resources, we've done it in 9 lines. The benefits of this increase the more "duplicates" you need to create.

It is worth keeping in mind though, that this might not be an appropriate method for every situation. If you were only creating 2 copies of a resource, this might be overkill rather than just writing the resource block for the 2 items. Equally, if you have lots of options for each object, it may become difficult to see what exactly will be created, and it is sometimes better to be verbose and clearly state your intentions for each unique resource block.
