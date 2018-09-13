#!/bin/bash

curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/mulesoft/docs-site-antora-ui/releases \
  | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin'))[0].assets[0].url)" \
  | curl -sL -o build/ui-bundle.zip --create-dirs -H "Accept: application/octet-stream" $(cat /dev/stdin)?access_token=$GITHUB_TOKEN
