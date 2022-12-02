---
title: 'Build a CloudFront invalidation CLI tool'
date: 'November 21, 2022'
description: 'Logging in to the AWS dashboard is a slow and inefficient way of creating cache invalidations so I built a simple CLI tool using the AWS CLI to speed things up.'
tags: ["aws", "shell-scripting", "tooling", "cloudfront"]
slug: 'cloudfront-invalidation'
layout: "../../layouts/PostLayout.astro"
---

## The problem

At work we use CloudFront as the main caching tool for our websites. It gives us a nice flexibility when we decide what needs caching, and for how long, and overall it works really nicely. 

Most of our clients are theatres, with the main function of their websites being to sell tickets, so as events are announced, we often want to show changes on cached pages very quickly.

This is where the problem presents itself. Getting login details for an AWS account from our password manager, logging in, finding the right distribution and creating an invalidation takes far too long through the dashboard. Especially when a client has made an important last minute change to an event page and they need it live right away.

It becomes even more frustrating if you are already logged into another AWS account and working on something, and you have to switch over quickly.

## The solution (sort of)

The first solution that came to mind first was to use the AWS CLI. It is really easy to use and since I already have AWS account profiles set up locally this would be a quick way to run an invalidation.

```bash
aws cloudfront create-invalidation \
    --distribution-id ID_HERE \
    --paths "PATH-HERE" \
    --profile "PROFILE-NAME-HERE"
```

But this also had problems.

1. You need to know the right commands. This is fine, but it's still a barrier to entry when you're trying to do something quickly.
2. You need to know the ID of the distribution you want to invalidate, and to get this you need to run `aws cloudfront list-distributions` and copy the distribution ID from the long JSON output.

![List CloudFront distributions with the AWS CLI](/assets/cloudfront-distros.gif "Cloudfront distributions")

I figured I can simplify this process by building a little script to hide some of these awkward processes.

## The better solution

With a few command line scripts we can make a reusable script which will let us create invalidations on any AWS account really quickly from the terminal.

### Prerequisites

- Have [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) installed
- Have some [profiles set up in your local config](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html) (`~./aws`)
- For this example [fzf](https://github.com/junegunn/fzf) is required to allow fuzzy searching on our list

The basic steps for bulding the tool are as follows:

1. Select an AWS profile from `~/.aws` with fzf
2. Use this profile to list any cloudfront distributions
3. Select a distribution with fzf
4. Get the distribution ID and use it to create an invalidation

### Build the app

1. Select a profile using the `list-profiles` command in the aws cli:

```bash
profile="$(aws configure list-profiles | fzf)"
```

2. Improve this list by ordering it with `sort`. Use the `-k` flag to sort results by key, and use the `-r` flag to reverse the output.

```bash
profile="$(aws configure list-profiles | sort -k 2 -r | fzf)"`
```

3. Once we've chosen a profile we need the distribution ID, so lets list the available distributions to work with, and pull out the data that is relevant to us:
	- Distribution ID
	- Name of the distribution so that we can select a human readable name

```bash
selected=$(printf "$(aws cloudfront list-distributions \
    --query 'DistributionList.Items[*].[Id,Origins.Items[0].Id]' \
    --output text \
    --profile $profile | fzf)")
```

The AWS CLI provides client-side filtering which we can utilise with the `--query` parameter. In the above example we instruct the CLI to only return the name of the distribution (`ID`) and the actual distribution ID (`Origins.Items[0].Id`). The `--output` parameter allows us to get the output in either JSON or plain text.

4. The selected item is saved to a variable so that we can work with the result to pull out the bits we want, for example we'll want the ID to pass into the invalidation command:

```bash
id=$(printf %s "$selected" | awk '{print $1}')
```

`awk` selects a piece of data based on a provided pattern - in this case we are telling it to print the contents of the first column, the ID

5. Now that we have our ID we need one more thing, the url, or path, that we want to invalidate. So if we want to invalidate the whats on page, our path might be `/whats-on`

```bash
read -p "Invalidation path: " path
```

`read` is a linux command which lets us take user input. We then save it to the variable path

6. The final command puts all of these bits together and we can finally run our invalidation command:

```bash
aws cloudfront create-invalidation \
    --distribution-id "$id" \
    --paths "$path" \
    --profile "$profile"
```

### Full code

5 lines of code and a few linux commands and we don't need to remember any AWS CLI commands or distribution IDs anymore.

```bash
profile="$(aws configure list-profiles | sort -k 2 | fzf)"

selected=$(printf "$(aws cloudfront list-distributions \
    --query 'DistributionList.Items[*].[Id,Origins.Items[0].Id]' \
    --output text \
    --profile $profile | fzf)")

id=$(printf %s "$selected" | awk '{print $1}')

read -p "Invalidation path: " path

aws cloudfront create-invalidation \
    --distribution-id "$id" \
    --paths "$path" \
    --profile "$profile"
```

Save your script as `something.sh` and run it from its directory with `./something.sh`. If this is your first shell script and you encounter a permissions error be sure to change the file permissions `chmod +x something.sh`.

![Create CloudFront invalidation](/assets/cloudfront-invalidation-final.gif "Cloudfront invalidations with the CLI")

You'll be presented with another JSON output which confirms that the invalidation status is InProgress, and if you check the invalidations via the AWS dashboard, you'll see your invalidation there too. It is rough around the edges, but it does the job.

## Summary

We wanted to run CloudFront invalidations without having to log into the AWS dashboard, and also without having to remember CLI commands or distribution IDs.

Using `fzf` and some basic linux commands we can wrap the AWS CLI commands, select an AWS account to work with from a list of preconfigured profiles, and run invalidations quickly and easily.

In the [next post](/posts/improving-cli-invalidations) we'll make this a nicer user experience using the [Charm.sh tool, Gum](https://github.com/charmbracelet/gum)
