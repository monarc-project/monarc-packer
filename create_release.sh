#!/usr/bin/env bash

# Check dependencies.
set -e
xargs=$(which gxargs || which xargs)

# Validate settings.
[ "$TRACE" ] && set -x

CONFIG=$@

for line in $CONFIG; do
	  eval "$line"
  done

  # Define variables.
  GH_API="https://api.github.com"
  GH_REPO="$GH_API/repos/$owner/$repo"
  AUTH="Authorization: token $github_api_token"
  WGET_ARGS="--content-disposition --auth-no-challenge --no-cookie"
  CURL_ARGS="-LJO#"

  API_JSON=$(printf '{"tag_name": "%s","target_commitish": "master","name": "%s","body": "Release s%s","draft": false,"prerelease": false}' $tag $tag $tag)

  # Construct url
  GH_ASSET="$GH_REPO/releases"

  curl "$GITHUB_OAUTH_BASIC" --data "$API_JSON" -H "$AUTH" -H "Content-Type: application/json" $GH_ASSET
