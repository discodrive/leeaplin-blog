---
title: 'Removing users from Heroku and WordPress Part 2 - Heroku'
date: 'December 5, 2022'
description: 'A simple script to easily remove users from Heroku Teams.'
tags: ["heroku", "shell-scripting", "tooling", "wordpress"]
slug: 'heroku-wordpress-user-management-part-2'
layout: "../../layouts/PostLayout.astro"
---

In the [last post](/posts/heroku-wordpress-user-management) we wrote a script to remove users from multiple WordPress sites hosted on Heroku. This time we'll finish clearing up the unneeded users with a script to remove them from Heroku Teams.

This post assumes that you are hosting your website on Heroku and have Teams set up. The script uses the Heroku CLI and a simple loop to go through each Team in your account, so ensure you have the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) installed.

## Heroku commands

The script will use 3 Heroku CLI commands:

- `heroku teams`
- `heroku members -t TEAM_NAME`
- `heroku members:remove EMAIL_ADDRESS -t TEAM`

The first command gathers all teams associated with your Heroku account. We'll save this to a variable and loop through each team.

`heroku members -t TEAM_NAME` lists the members as we loop through each team.

Finally the last command will remove the specified user from the team.

It is also necessary to check if the specified user actually exists in the team before trying to remove them, and this will also allow for a message to let us know if the user does not exist on the team.

## Full code

```shell
#!/bin/bash
EMAIL=$1
TEAMS=$(heroku teams | awk '{print $1;}')
for TEAM in $TEAMS
do
    USER=$(heroku members -t "$TEAM" | awk '{print $1;}' | grep "EMAIL")
    if [ -n "$USER" ]; then
        heroku members:remove "$EMAIL" -t "$TEAM"
    else
        printf "User: %s does not exist.\n" "${EMAIL}"
    fi
done
```

- The email address comes from the first argument after calling the script. For example `./delete-users.sh test@email.com` will delete any user in a team which has the email address `test@email.com`.
- `heroku teams` returns team names and your role in that team. The role is not required so `awk '{print $1;}'` ensures we only return the first column, which is the team name.
- The teams names are all assigned to the `TEAMS` variable, and we loop over them.
- `heroku members -t "$TEAM"` gets the team members for each team as we iterate over the teams array. This command also returns member roles, and the status (if they are pending for example), so we use `awk` again to return only the first column, as well as `grep` to check if the email address matches the one we input.
- If there is a match, we use `if [ -n "$USER"]` to make sure the variable is not empty, and then we run `heroku members:remove` passing in the email address and the current team name. This will remove the user.
- If there is no match we return a message to say so.

## Summary

The goal was to write a script which would take an email address as an input, loop through Heroku Teams that we are a member of and check if that email address is associated with a user in the team. If it is, delete this user, otherwise return a message to let us know that the user doesn't exist.

This is a nice lightweight script which leverages the Heroku CLI with a couple of conditions to make sure we're removing the right user, and save API requests if the user doesn't exist.
