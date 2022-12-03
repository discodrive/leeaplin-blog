---
title: 'Removing users from Heroku and WordPress'
date: 'December 2, 2022'
description: Removing users from multiple projects can be laborious, so figuring out how to automate this boring and time consuming task is a good idea.'
tags: ["heroku", "shell-scripting", "tooling", "wordpress"]
slug: 'heroku-wordpress-user-management'
layout: "../../layouts/PostLayout.astro"
---

## User management

Colleagues frequently leave for new roles, but leaving all of these unused-users in projects can be a security risk, so they need to be removed efficiently. Manually editing roles and permissions on multiple projects is the opposite of efficient, so using a script to do this for you can save lots of time and effort.

I recently wrote a couple of scripts for removing unneeded users from websites hosted on Heroku and using WordPress.

## Removing users from WordPress

This script utilises the WordPress CLI which is included in the root of our WordPress projects. The CLI command for removing a WordPress user is actually very simple, and will be the main command used in the script:

```shell
wp user delete USER_EMAIL
```

To reassign content that was attached to this user, you can append the `--reassign=USER_ID` flag to this command. This is important because content which is not reassigned is deleted.

### Requirements for the script

The script needs to check if the user we are removing actually exists, and if it does, reassign the content automatically to another user on the same domain. For example, the user being deleted is `test@example.com` so we want to reassign content to another user with an `@example.com` email address.

As it runs, a message will be returned to show whether a user was deleted, or if they didn't exist on a specific project. 

### Build the script

1. The script will take a single arguement, the email address of the user we want to remove. It will also need to check existing users to determine if the target user exists:

```shell
EMAIL=$1
USERS="$(wp user list --fields=ID,user_email | grep @example)"
```

Using the `--fields` flag we can get the ID and email address of the current WordPress users. We pipe this result into a grep that returns only the users with `@example` in the address.

In my case, I wasn't more specific, because some users have `.co.uk` and others have `.com`.

2. Next a check needs to be added to see if the target user exists in the `$USERS` array.

```shell
if grep -qs "${EMAIL}" <<< "$USERS"; then
	...
fi
```

Grep checks if the target exists in the array. `-qs` will quiet the output and suppress errors - this is just acting as a conditional check so we dont need any output.

3. Find the first user which matches your search criteria and set it as a variable. Then use this to set variables for the ID and email address of the user. These are required later.

```shell
USER="$(echo "$USERS" | sed -n 1p)"
USER_ID=$(echo "$USER" | awk '{print $1}')
USER_EMAIL=$(echo "$USER" | awk '{print $2}')
```

`sed -n 1p` will extract the first line (get our first matching user). The `-n` option will supress the unmatched text, and the `p` means "print the matching lines". The result would look like `1 user@example.com`

`awk` gets the content from the specified column, so `USER_ID` would be 1, and `USER_EMAIL` would be `user@example.com`.

4. If the email input matches the queried user, reassign the USER_ID variable to the next valid user. This is so that we can reassign the deleted users content to the next suitable user.

```shell
if grep -qs "${EMAIL}" <<< "$USER_EMAIL"; then
	USER_ID="$(echo "$USERS" | sed -n 2p | awk '{print $1;}')"
fi
```

These commands work in the same way as the previous checks, except this time `sed -n 2p` returns the second line, rather than the first.

5. Finally, after gathering all of the required info, the delete command can be used to delete the user and reassign the content.

```shell
wp user delete "${EMAIL}" --reassign="${USER_ID}"
```

### Full code

```shell
#!/bin/bash

# Email address of the user to delete. Save it to a variable for checks.
EMAIL=$1
USERS="$(wp user list --fields=ID,user_email | grep @example)"

# Check if the specified email address is a user on the site
if grep -qs "${EMAIL}" <<< "$USERS"; then

	# Find the first example user. Set variables for the ID and Email address
	USER="$(echo "$USERS" | sed -n 1p)"
	USER_ID=$(echo "$USER" | awk '{print $1}')
	USER_EMAIL=$(echo "$USER" | awk '{print $2}')
	
	# If the email input matches the queried user, reassign the USER_ID variable to the next valid user
	if grep -qs "${EMAIL}" <<< "$USER_EMAIL"; then
		USER_ID="$(echo "$USERS" | sed -n 2p | awk '{print $1;}')"
	fi
	
	# Delete the user and reassign
	wp user delete "${EMAIL}" --reassign="${USER_ID}"
	
	printf "User: %s deleted. Content reassigned to %s" "${EMAIL}" "${USER_EMAIL}"
else
	printf "Selected user does not exist"
fi
```

Finish off with some user feedback, a success message if the user was deleted, or a message if the user doesn't exist.

## Running the script

This script was designed to be run across multiple WordPress installations on different Heroku servers and we have 70+ projects which would require this kind of maintenance.

To run this script on Heroku, the Heroku CLI comes in handy. The are a couple of prerequisites before running it.

### Prerequisites

- Install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)
- Install the Heroku `apps-table` plugin with `heroku plugins:install apps-table`. This allows you to interact with all apps in your account without having to specify the name of an app. [Read the documentation for available commands](https://socket.dev/npm/package/@heroku-cli/plugin-apps-table).
- The script will need to be hosted somewhere such as a git repo so that it can be accessed remotely. This is because you'll need to Bash into each Heroku app to run the wp-cli scripts on your WordPress installation.

### Run command

The command to run the script across all of your Heroku apps looks like this:

```shell
heroku apps:table \
--filter="App Name=-example" \
--columns="app name" \
--no-header | \
xargs -n 1 heroku run "bash <(curl -s https://raw.githubusercontent.com/username/script-name.sh) user@example.com" -a
```

This command will loop through all of the heroku apps whose name contains `-live`. 

- The `--filter` flag is flexible. You can speficy an exact app name, or you can use partials such as `-example` to get all apps named `*-example`. If you append your app names with something like `-example` you can easily group them
- `--columns` only shows provided columns
- `--no-header` hides the heroku table header from output
- `xargs` then passes this list of apps through to the next command
- `heroku run "bash <(curl -s https://raw.githubusercontent.com/username/script-name.sh) user@example.com"` Each Heroku app will run the script from its remote location, in this case a github repo
- Finally the `-a` flag specifies that we want to run the script on every app in the list.

## Summary

This script allows you to loop through all of your Heroku hosted WordPress sites and delete a specified user from all of them quickly.

In the next post we'll write a script to remove users from multiple Heroku teams.
