#!/usr/bin/env bash

set -x
TASK_PATH="$1"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Add mocks to the beginning of all task step scripts (step 0 and 1)
for i in 0 1; do
  yq -i ".spec.steps[$i].script = load_str(\"$SCRIPT_DIR/mocks.sh\") + .spec.steps[$i].script" "$TASK_PATH"
done
