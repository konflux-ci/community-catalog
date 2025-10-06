#!/usr/bin/env bash

set -euxo pipefail

# mocks to be injected into task step scripts
function git() {
  echo "Mock git called with: $*"

  if [[ "$*" == *"clone"* ]]; then
    gitRepo=$(awk '{print $NF}' <<< $*)
    mkdir -p "$gitRepo"/components/internal-services/internal-staging
    echo "image: quay.io/konflux-ci/internal-services:old" | tee \
      "$gitRepo"/components/internal-services/internal-staging/manager-one.yaml \
      "$gitRepo"/components/internal-services/internal-staging/manager-two.yaml \
      "$gitRepo"/components/internal-services/internal-staging/manager-three.yaml
    mkdir -p "$gitRepo"/components/internal-services/internal-production
    echo "image: quay.io/konflux-ci/internal-services:old" | tee \
      "$gitRepo"/components/internal-services/internal-production/manager-one.yaml \
      "$gitRepo"/components/internal-services/internal-production/manager-two.yaml \
      "$gitRepo"/components/internal-services/internal-production/manager-three.yaml
  else
    # Mock the other git functions to pass
    : # no-op - do nothing
  fi
}

function gh() {
  echo "Mock gh called with: $*"
}
