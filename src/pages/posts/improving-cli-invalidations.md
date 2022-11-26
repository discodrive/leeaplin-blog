---
title: 'Improving the UI of the CloudFront invalidation CLI tool'
date: 'November 26, 2022'
description: 'Giving the CloudFront invalidation tool from the last post a nicer UI using Gum from Charm.sh'
tags: ["aws", "shell-scripting", "tooling", "cloudfront"]
slug: 'improving-cli-invalidations'
layout: "../../layouts/PostLayout.astro"
---

The CloudFront invalidation tool that we built in the [last post](/posts/cloudfront-invalidation) does the job but it doesn't look very nice and doesn't give very useful feedback to the user.

## Problems with the UI

The first main issue with the simple invalidation script is that if you are interacting with an AWS profile with several CloudFront distributions, it can take some time to retrieve them. This means that the user can be waiting around for the distributions request to respond, with no visual clues to show that things are working as expected.

Next, it would be nice to have a chance to review what is being invalidated, and confirm that the invalidation path is correct.

The last issue we will deal with is the final response received after creating an invalidation. Once an invalidation path is provided, the user is presented with a JSON response which shows the invalidation ID, the path being invalidated and the status of the invalidation. For the purposes of this script, we don't really need all of this info, we just want to know whether or not the invalidation was successfully created.

## Adding some style

I really like the tools made by [Charm.sh](https://github.com/charmbracelet) and [Gum](https://github.com/charmbracelet/gum) is great for jazzing up shell scripts, so we can use this to improve the UI.
