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

On a mac Gum is easy to install with `brew install gum`. Check the [docs for other installation methods](https://github.com/charmbracelet/gum#installation).

Once it's installed, Gum provides lots of options for fancying up interactions in the command line. There are options for fuzzy filtering, choosing from a list of options (plus multi-selection), confirmation boxes as well as loading/status spinners with multiple animation options.

We can use filtering, a loading spinner, an input prompt, a confirmation and some general gum styling.

### Filtering

The Gum filtering works pretty much the same as the fzf filtering, but since we're using Gum for other things, we'll use it for the filtering too. It does let us add a placeholder message as well though:

```shell
profile="$(aws configure list-profiles | sort -k 2 | gum filter --placeholder='Select a profile...')"
```

### Loading spinner

When you have selected your profile and it is pulling in the distributions there can be a short delay. Rather than leaving the user hanging we can add a spinner here to show that something is actually happening. We'll pipe the returned distributions list into a filter.

The spinner displays while a script or command is running, and automatically stops when it exits.

```shell
selected=$(printf "$(gum spin \
    --spinner line \
    --title 'Finding distributions' \
    --show-output -- aws cloudfront list-distributions \
    --query 'DistributionList.Items[*].[Origins.Items[0].Id,Id]' \
    --output text \
    --profile $profile | gum filter)")
```

### Input prompt

This works in exactly the same way as the `read` command that we used before, but it is styled nicely. We could prompt for sensitive information with the `--password` flag.

```shell
path="$(gum input --placeholder 'Enter an invalidation path:')"
```

### Confirmation

The confirm interaction gives us a chance to review the invalidation and either confirm or cancel it. In this case we set a message variable to let the user know if the invalidation is being created or not.

```shell
message="Invalidation successfully created."

gum confirm "Invalidate the CloudFront cache for $name distribution on the following path: $path" && \
gum spin --spinner line --title 'Creating the invalidation...' -- aws cloudfront create-invalidation \
    --distribution-id "$id" \
    --paths "$path" \
    --profile "$profile" || message="No invalidation created."
```

### Custom styled confirmation message

Finally we return our confirmation message which says whether or not the invalidation was created. Sleep stops the script for 2 seconds to allow users to read the final message, which then automatically closes itself.

```shell
gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    "$message"

sleep 2
```

## Full code

```shell
#!/bin/bash

# Select a profile using gum filter
profile="$(aws configure list-profiles | sort -k 2 | gum filter --placeholder='Select a profile...')"

# Use the selected profile to list distributions and select with gum filter, prompt for an invalidation path
selected=$(printf "$(gum spin 
    --spinner line 
    --title 'Finding distributions' 
    --show-output 
    -- aws cloudfront list-distributions 
    --query 'DistributionList.Items[*].[Origins.Items[0].Id,Id]' 
    --output text 
    --profile "$profile" | gum filter)")
name=$(printf %s "$selected" | awk '{print $1}')
id=$(printf %s "$selected" | awk '{print $2}')
path="$(gum input --placeholder 'Enter an invalidation path:')"

message="Invalidation successfully created."

# Create the invalidation using the selected ID and the invalidation path
gum confirm "Invalidate the CloudFront cache for $name distribution on the following path: $path" && \
gum spin --spinner line --title 'Creating the invalidation...' -- aws cloudfront create-invalidation \
    --distribution-id "$id" \
    --paths "$path" \
    --profile "$profile" || message="No invalidation created."

gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 50 --margin "1 2" --padding "2 4" \
    "$message"

sleep 2
```

The whole process will look something like this:

![Create CloudFront invalidation](/assets/gum-invalidations.gif "Styled Cloudfront invalidations with the CLI")

## Finishing touches

This script can be run by navigating to its directory, but it's quicker and easier if it can be run from anywhere. I did this easily with a tmux shortcut. If you use tmux, edit your `.tmux.conf` file and add a new key binding to run the script from anywhere when you have a tmux session open. I use `<leader> o` which opens a new tmux window, and closes it again when the script is finished:

```shell
bind-key -r o run-shell "tmux neww ~/shell-scripts/invalidation.sh"
```

## Summary

Adding some styling to the CLI tool using [Gum by Charm.sh](https://github.com/charmbracelet/gum) helps to improve the UI and give a user some feedback which was missing from the simple script. Gum gives the flexibility to completely restyle and customise the user experience and adds a bit of flair to a CLI utility.
