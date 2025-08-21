#!/usr/bin/env bash

# SC2016 - "Expressions don't expand in single quotes, use double quotes for that." 
# is disabled because we need to use single quotes in some cases

# shellcheck disable=SC2016
set -eux

# mocks to be injected into task step scripts

function kubectl() {
  # Don't echo debug output to avoid interfering with the actual return value
  echo $* >> /tmp/mock_kubectl.txt

  if [[ "$*" == *"get snapshot"* ]]; then
    # Mock snapshot response for default/konflux-test-container-98765
    cat > /tmp/mock_snapshot.json <<EOF
{
  "spec": {
    "components": [
      {
        "containerImage": "quay.io/example/konflux-test-container:latest"
      }
    ]
  }
}
EOF
    cat /tmp/mock_snapshot.json
  else
    echo Error: Unexpected kubectl call: $*
    exit 1
  fi
}

function skopeo() {
  # Don't echo debug output to avoid interfering with the actual return value
  echo $* >> /tmp/mock_skopeo.txt

  if [[ "$*" == *"inspect docker://"* ]]; then
    # Mock skopeo inspect response with the required labels for any image
    cat > /tmp/mock_skopeo_inspect.json <<EOF
{
  "Labels": {
    "vcs-ref": "abc123def456",
    "url": "https://github.com/example/konflux-test-container.git"
  }
}
EOF
    cat /tmp/mock_skopeo_inspect.json
  else
    echo Error: Unexpected skopeo call: $*
    exit 1
  fi
}

function jq() {
  # Don't echo debug output to avoid interfering with the actual return value
  echo $* >> /tmp/mock_jq.txt

  if [[ "$*" == *".spec.components[0].containerImage"* ]]; then
    echo "quay.io/example/konflux-test-container:latest"
  elif [[ "$*" == *".spec.components[].containerImage"* ]]; then
    echo "quay.io/example/konflux-test-container:latest"
  elif [[ "$*" == *".Labels[\"vcs-ref\"]"* ]]; then
    echo "abc123def456"
  elif [[ "$*" == *".Labels[\"url\"]"* ]]; then
    echo "https://github.com/example/konflux-test-container.git"
  elif [[ "$*" == *".transitions[] | select(.name==\"ON_QA\") | .id"* ]]; then
    echo "123"
  elif [[ "$*" == *".fields.status.name"* ]]; then
    echo "ON_QA"
  elif [[ "$*" == *".servers[] | contains"* ]]; then
    echo "rest/api/2/issue"
  elif [[ "$*" == *".[0] | \"\\(.title)\""* ]]; then
    echo "OCPBUGS-12345: Fix important OCP issue"
  elif [[ "$*" == *"[] | select(.servers[] | contains"* ]]; then
    echo "rest/api/2/issue"
  elif [[ "$*" == *"select(.servers[] | contains"* ]]; then
    echo "rest/api/2/issue"
  else
    echo Error: Unexpected jq call: $*
    exit 1
  fi
}

function gh() {
  # Don't echo debug output to avoid interfering with the actual return value
  echo $* >> /tmp/mock_gh.txt

  if [[ "$*" == *"auth login --with-token"* ]]; then
    # Mock GitHub auth login - just return success
    echo "✓ Logged in to github.com (oauth_token)"
    return 0
  elif [[ "$*" == *"api repos"* ]]; then
    # Mock GitHub API response for pull request
    cat > /tmp/mock_gh_response.json <<EOF
[
  {
    "title": "OCPBUGS-12345: Fix important OCP issue"
  }
]
EOF
    cat /tmp/mock_gh_response.json
  else
    echo Error: Unexpected gh call: $*
    exit 1
  fi
}

function curl-with-retry() {
  # Don't echo debug output to avoid interfering with the actual return value
  echo $* >> /tmp/mock_curl.txt

  if [[ "$*" == *"transitions"* ]]; then
    # Mock transitions API response
    cat > /tmp/mock_transitions.json <<EOF
{
  "transitions": [
    {
      "id": "123",
      "name": "ON_QA"
    }
  ]
}
EOF
    cat /tmp/mock_transitions.json
  elif [[ "$*" == *"rest/api/2/issue"* ]] && [[ "$*" != *"transitions"* ]] && [[ "$*" != *"comment"* ]]; then
    # Mock issue status API response
    cat > /tmp/mock_issue_status.json <<EOF
{
  "fields": {
    "status": {
      "name": "ON_QA"
    }
  }
}
EOF
    cat /tmp/mock_issue_status.json
  else
    echo Error: Unexpected curl-with-retry call: $*
    exit 1
  fi
}
