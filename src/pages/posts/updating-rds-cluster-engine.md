---
title: 'Updating RDS Aurora clusters'
date: 'December 11, 2022'
description: 'Amazon Aurora MySQL 1 reaches end of life in February 2023, so with over 100 databases to update I wrote a very simple script to do it quickly.'
tags: ["aws", "shell-scripting", "tooling", "rds"]
slug: 'updating-rds-cluster-engine'
layout: "../../layouts/PostLayout.astro"
---

## Upgrading the database manually

Upgrading RDS Aurora cluster engines is very easy via the AWS dashboard by modifying the cluster and choosing a new engine. Select a suitable maintenance window and schedule the update to happen. Since upgrading a database engine requires downtime this needs to be done during the night, or a low traffic period.

But doing it manually is hard work when you have hundreds of databases to manage and writing a script to do them all at once is fairly straightforward.

## Using AWS CLI

This script uses 4 CLI commands:

- `aws configure list-profiles` lists all of the profiles in an AWS credentials file
- `aws configure get region --profile profile_name` gets the region of each profile. This is necessary because not all of the AWS accounts are in the same location.
- `aws rds describe-db-clusters` returns information about the Aurora clusters in the account. The important bits are the Cluster Identifier and the Engine Version, which can be filtered out using the `--query` arguement. The engine version helps identify which clusters need upgrading, and the identifier is used in the last command.
- `aws rds modify-db-cluster` is used to update the engine version of the outdated clusters.

## Build the script

1. Loop over all of the AWS profiles in the AWS credentials file:

```shell
profiles="$(aws configure list-profiles)"

for profile in $profiles
do
...
done
```

2. Get the region for each profile. This is required in the final command:

```shell
r=$(aws configure get region --profile "$profile")
```

3. Get the RDS clusters and filter out the ones which need upgrading. In this case these are any which are still using MySQL version 5.6 (Aurora version 1):

```shell
cluster=$(aws rds describe-db-clusters --query "*[].{DBClusterIdentifier:DBClusterIdentifier,EngineVersion:EngineVersion}" --output text --profile "$profile" --region "$r" --no-cli-pager | grep 5.6 | awk '{print $1;}')
```

The list of clusters to be updated are saved to a `$clusters` varable for use in the final command. The `--query` argument is used to retrieve the `DBClusterIdentifier` and the `EngineVersion`.

`grep 5.6` filters out only results which use MySQL 5.6, and `awk '{print $1;}'` returns the first column of data, which is the Cluster Identifier.

4. Check if `$clusters` is not empty, and then modify each cluster in the list to upgrade to Aurora version 2. A prefered maintenance window is declared to make sure this action happens during the night, because upgrading a database cluster requires downtime:

```shell
if [ -n "$clusters" ];then
    for cluster in $clusters
    do
        aws rds modify-db-cluster \
            --db-cluster-identifier "$cluster" \
            --engine-version "5.7.mysql_aurora.2.11.0" \
            --preferred-maintenance-window "Wed:03:00-Wed:04:00" \
            --region "$r" \
            --profile "$profile" \
            --no-cli-pager
    done
fi
```

The previously set variables for region and profile are passed in, as well as the cluster identifier from the last command.

The `--no-cli-pager` argument prevents the JSON output each time the command completes, because this interrupts the script as it requires that the window is manually closed.

## Full code

```shell
#!/bin/bash

profiles="$(aws configure list-profiles)"

for profile in $profiles
do
    r=$(aws configure get region --profile "$profile")
    clusters=$(aws rds describe-db-clusters --query "*[].{DBClusterIdentifier:DBClusterIdentifier,EngineVersion:EngineVersion}" --output text --profile "$profile" --region "$r" --no-cli-pager | grep 5.6 | awk '{print $1;}')

    if [ -n "$clusters" ];then
        for cluster in $clusters
        do
            aws rds modify-db-cluster \
                --db-cluster-identifier "$cluster" \
                --engine-version "5.7.mysql_aurora.2.11.0" \
                --preferred-maintenance-window "Wed:03:00-Wed:04:00" \
                --region "$r" \
                --profile "$profile" \
                --no-cli-pager
        done
    fi
done
```

This and other shell scripts can be found in my [Github shell scripts repo](https://github.com/discodrive/shell-scripts).

## Summary

The goal for this script was to quickly update all deprecated RDS clusters from Aurora version 1 to version 2. It's a very specific use case, but it demonstrates how using the AWS CLI can save a lot of time when it comes to repetitive maintenance tasks.
