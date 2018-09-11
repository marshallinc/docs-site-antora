#!/bin/bash

curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/mulesoft/docs-site-antora-ui/releases \
  | tr '\n' ' ' | grep -oP '"assets":.*?"id":[^,]+' | head -1 | grep -oP '[0-9]+$' \
  | curl -L -o build/ui-bundle.zip --create-dirs -H "Accept: application/octet-stream" https://api.github.com/repos/mulesoft/docs-site-antora-ui/releases/assets/$(cat /dev/stdin)?access_token=$GITHUB_TOKEN
