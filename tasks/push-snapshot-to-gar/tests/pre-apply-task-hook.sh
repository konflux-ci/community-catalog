#!/usr/bin/env bash

set -x
TASK_PATH="$1"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Inject mocks into the task step script (step 0 only, single step task)
yq -i '.spec.steps[0].script = load_str("'"$SCRIPT_DIR"'/mocks.sh") + .spec.steps[0].script' "$TASK_PATH"

# Create the WIF config ConfigMap (normally provisioned by the user)
kubectl create configmap gar-wif-config \
  --from-literal=config.json='{"type":"external_account","audience":"test","token_url":"https://sts.googleapis.com/v1/token","credential_source":{"file":"/var/run/secrets/tokens/oidc-token","format":{"type":"text"}}}' \
  --dry-run=client -o yaml | kubectl apply -f -

# Replace the projected SA token volume with an emptyDir and create a fake token file
# The test cluster does not have an OIDC issuer, so projected tokens cannot be created
yq -i '.spec.volumes[] |= (select(.name == "oidc-token") | .projected = null | .emptyDir = {})' "$TASK_PATH"

# Add an init step to create a fake OIDC token file
yq -i '.spec.steps = [{"name": "create-fake-token", "image": "registry.access.redhat.com/ubi9/ubi-minimal:latest", "script": "#!/usr/bin/env bash\nmkdir -p /var/run/secrets/tokens\necho fake-oidc-token > /var/run/secrets/tokens/oidc-token\n", "volumeMounts": [{"name": "oidc-token", "mountPath": "/var/run/secrets/tokens"}]}] + .spec.steps' "$TASK_PATH"
