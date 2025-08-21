#!/usr/bin/env bash

set -x
TASK_PATH="$1"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Add mocks to the beginning of task step script
yq -i '.spec.steps[0].script = load_str("'$SCRIPT_DIR'/mocks.sh") + .spec.steps[0].script' "$TASK_PATH"

# Create a dummy jira secret (and delete it first if it exists)
kubectl delete secret konflux-jira-secret --ignore-not-found
kubectl create secret generic konflux-jira-secret --from-literal=token=dummy-token

# Create a dummy github secret (and delete it first if it exists)
kubectl delete secret konflux-github-secret --ignore-not-found
kubectl create secret generic konflux-github-secret --from-literal=token=dummy-token
