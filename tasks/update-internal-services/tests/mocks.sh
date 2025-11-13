#!/usr/bin/env bash

set -euxo pipefail

# mocks to be injected into task step scripts
function git() {
  echo "Mock git called with: $*"
  gitRepo=$(awk '{print $NF}' <<< $*)

  if [[ "$*" == *"clone"*"internal-services" ]]; then
    mkdir -p "$gitRepo"/config/crd/bases
    echo "foo" | tee "$gitRepo"/config/crd/bases/crd.yaml
    mkdir -p "$gitRepo"/config/rbac
    echo "foo" | tee "$gitRepo"/config/rbac/role_binding.yaml
  elif [[ "$*" == *"clone"* ]]; then
    mkdir -p "$gitRepo"/components/internal-services/internal-staging/manager
    echo "image: quay.io/konflux-ci/internal-services:old" | tee \
      "$gitRepo"/components/internal-services/internal-staging/manager/manager-one.yaml \
      "$gitRepo"/components/internal-services/internal-staging/manager/manager-two.yaml \
      "$gitRepo"/components/internal-services/internal-staging/manager/manager-three.yaml
    mkdir -p "$gitRepo"/components/internal-services/internal-production/manager
    echo "image: quay.io/konflux-ci/internal-services:old" | tee \
      "$gitRepo"/components/internal-services/internal-production/manager/manager-one.yaml \
      "$gitRepo"/components/internal-services/internal-production/manager/manager-two.yaml \
      "$gitRepo"/components/internal-services/internal-production/manager/manager-three.yaml
    mkdir -p "$gitRepo"/components/internal-services/base/crd
    mkdir -p "$gitRepo"/components/internal-services/base/rbac
  elif [[ "$*" == 'git log --format="%H"'* ]]; then
      echo abcdefg
      echo zyxwvu
      echo 123456
  elif [[ "$*" == 'git log --format="%s"'* ]]; then
      echo "chore: this is an example git commit title"
  else
    # Mock the other git functions to pass
    : # no-op - do nothing
  fi
}

function gh() {
  echo "Mock gh called with: $*"
}
