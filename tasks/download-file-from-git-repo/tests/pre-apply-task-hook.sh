#!/usr/bin/env bash

set -x
TASK_PATH="$1"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Add mocks to the beginning of task step script
yq -i '.spec.steps[0].script = load_str("'$SCRIPT_DIR'/mocks.sh") + .spec.steps[0].script' "$TASK_PATH"

# Create test secrets for private repo tests
kubectl delete secret private-token --ignore-not-found
kubectl delete secret gitlab-token --ignore-not-found
kubectl delete secret invalid-secret --ignore-not-found
kubectl delete secret empty-token --ignore-not-found

kubectl create secret generic private-token --from-literal=token=dG9rZW4tZm9yLXByaXZhdGUtcmVwbw==
kubectl create secret generic gitlab-token --from-literal=token=Z2l0bGFiLXRva2Vu
kubectl create secret generic invalid-secret --from-literal=wrongkey=value
kubectl create secret generic empty-token --from-literal=token=""

# Clean up any existing temporary files
rm -f /tmp/mock_curl.txt 
