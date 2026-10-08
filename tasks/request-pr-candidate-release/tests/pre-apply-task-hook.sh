#!/usr/bin/env bash
set -euo pipefail

TASK_PATH="$1"
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export SCRIPT_DIR

# Keep the original script's errexit behavior in a subshell. Check its observed
# API effects afterwards, including for cases whose Task is expected to fail.
# shellcheck disable=SC2016 # Tekton must receive the literal parameter reference.
yq -i '
  .spec.steps[0].env += [{"name": "PR_CANDIDATE_TEST_CASE", "value": "$(params.SNAPSHOT)"}] |
  .spec.steps[0].script = load_str(strenv(SCRIPT_DIR) + "/mocks.sh") +
    "\nset +e\n(\n" + .spec.steps[0].script +
    "\n)\nTASK_EXIT=$?\nassert_task_outcome \"$TASK_EXIT\"\n"
' "$TASK_PATH"
