---
title: 'Fixing CloudFront problems with page redirects'
date: 'December 19, 2022'
description: 'I recently had problems with CloudFront not caching a page as expected because of a redirect. Here is a quick review of the issue and how to fix it.'
tags: ["caching", "cloudfront", "bug-fixing"]
slug: 'cloudfront-redirects-problems'
layout: "../../layouts/PostLayout.astro"
---


## The problem

While I was setting up a pretty straight forward CloudFront distribution for a client, I had some trouble getting their events page to cache correctly.

The page loaded fine and would cache without any issues if you refreshed it, but the problem was related to using event filters and a search option on the page. Usually this doesn't present any difficulties:

- A custom cache policy is set up to handle the `whats-on` page
- An **allowed list** is set up for any query strings that need to be used on the page
- Each time a different combination of query strings is used, in this case by changing the filtering options, a new cache key is created

!["Filters on the whats-on page"](/assets/filters.jpg "Website filters")

But for some reason this time the first set of filters applied would work correctly, and the page would cache as expected, but any subsequent changes would still show the results these initial filters.

## The solution

Firstly, I checked the cache policies to make sure nothing was awry, but everything looked as expected.

A quick way to check your policies without having to manually sort through them all in the AWS dashboard is with:

`aws cloudfront list-cache-policies --type custom  --profile PROFILE_NAME --output table`

!["List cache policies with the AWS CLI"](/assets/cache-policies-cli.jpg "AWS cache policies cli output")

After checking the cache policies and distribution settings, I started checking the responses in the Network tab in the developer tools, and this is where I found the problem.

On this particular site, the forms used for the filters had hard coded actions to reload the page after submission. The URL of the page was `/whats-on/`, but the form action was to `/whats-on`. Note the missing trailing slash.

!["Multiple request URLs in the network tab"](/assets/multiple-caches.jpg "Multple request URLs")

In addition, the site was configured to redirect any URL visited to include the trailing slash. This meant that CloudFront was caching two versions of the page and getting itself into a bit of confusion about which version to serve and when. This was further exacerbated when using different combinations of query strings.

The solution was simple: Make sure that the action on the form matched the expected page URL. Preventing this redirect when using filters meant that we only saw a single cached page from CloudFront, and everything loaded as expected.

## Summary

Sometimes the cause of a CloudFront caching problem can be as simple as an unexpected redirect, or a missing trailing slash. Small details like this are easily overlooked, and you'll find yourself spending hours debugging configurations which were fine in the first place.

Hopefully this can help someone else who is struggling to figure out why CloudFront isn't caching a page as expected.
