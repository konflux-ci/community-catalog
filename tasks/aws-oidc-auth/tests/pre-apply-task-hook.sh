#!/usr/bin/env bash

set -x
TASK_PATH="$1"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)

# Install the StepAction that the Task references
STEPACTION_PATH="${REPO_ROOT}/stepactions/aws-oidc-auth/aws-oidc-auth.yaml"
STEPACTION_COPY=$(mktemp)
cp "$STEPACTION_PATH" "$STEPACTION_COPY"

# Add mocks to the StepAction script
yq -i '.spec.script = load_str("'"$SCRIPT_DIR"'/mocks.sh") + .spec.script' "$STEPACTION_COPY"
kubectl apply -f "$STEPACTION_COPY"
rm -f "$STEPACTION_COPY"

# Replace the projected serviceAccountToken volume with an emptyDir
# since kind clusters don't have a real OIDC provider
yq -i '.spec.volumes[0] = {"name": "oidc-token", "emptyDir": {}}' "$TASK_PATH"

# Prepend a step that creates a fake OIDC token
yq -i '.spec.steps = [
  {
    "name": "setup-fake-token",
    "image": "registry.access.redhat.com/ubi9-minimal:latest",
    "volumeMounts": [{"name": "oidc-token", "mountPath": "/var/run/secrets/oidc"}],
    "script": "#!/bin/bash\necho -n \"eyJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczovL3Rlc3QiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6dGVzdC1uczp0ZXN0LXNhIiwiYXVkIjpbInN0cy5hbWF6b25hd3MuY29tIl19.fake-signature\" > /var/run/secrets/oidc/token"
  }
] + .spec.steps' "$TASK_PATH"
