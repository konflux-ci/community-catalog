#!/usr/bin/env bash
set -euo pipefail

# Run the actual embedded script, changing only API responses and elapsed time.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TASK_PATH=${1:-"$SCRIPT_DIR/../request-pr-candidate-release.yaml"}
ARTIFACTS=$(mktemp -d)
export ARTIFACTS
yq -r '.spec.steps[0].script' "$TASK_PATH" > "$ARTIFACTS/production-script.sh"
failures=0

for probe in newline-application newline-component newline-revision newline-sha \
  newline-terminal-status poll-after-deadline api-elapsed-time; do
  set +e
  (
    export PR_CANDIDATE_TEST_CASE=success
    if [[ "$probe" == newline-terminal-status || "$probe" == poll-after-deadline || "$probe" == api-elapsed-time ]]; then
      PR_CANDIDATE_TEST_CASE=timeout-idempotency
    fi
    # Retain the complete inherited mock, with its kubectl function renamed so
    # this focused test can observe and model time spent at the API boundary.
    # shellcheck source=/dev/null
    source <(sed 's/^kubectl() {/fixture_kubectl() {/' "$SCRIPT_DIR/mocks.sh")
    printf '%s\n' "$MOCK_STATE" > "$ARTIFACTS/$probe-state"
    BASE_SNAPSHOT=$(mock_snapshot)
    if [[ "$probe" == newline-terminal-status ]]; then
      BASE_RELEASE=$(mock_release True)
      # Called indirectly by the inherited Release API mock.
      # shellcheck disable=SC2329
      mock_release() {
        jq '(.status.conditions[] | select(.type == "ManagedPipelineProcessed").status) = "True\n"' <<< "$BASE_RELEASE"
      }
    fi
    export SNAPSHOT=$PR_CANDIDATE_TEST_CASE TASKRUN_NAMESPACE=default
    # Called indirectly by the inherited Snapshot API mock.
    # shellcheck disable=SC2329
    mock_snapshot() {
      case "$probe" in
        newline-application)
          jq '.spec.application += "\n" | .metadata.labels["appstudio.openshift.io/application"] += "\n"' <<< "$BASE_SNAPSHOT"
          ;;
        newline-component) jq '.spec.components[0].name += "\n"' <<< "$BASE_SNAPSHOT" ;;
        newline-revision) jq '.spec.components[0].source.git.revision += "\n"' <<< "$BASE_SNAPSHOT" ;;
        newline-sha)
          jq '.spec.components[0].source.git.revision += "\n" | .metadata.labels["pac.test.appstudio.openshift.io/sha"] += "\n"' <<< "$BASE_SNAPSHOT"
          ;;
        *) printf '%s\n' "$BASE_SNAPSHOT" ;;
      esac
    }
    # Called by the real production script sourced below.
    # shellcheck disable=SC2329
    kubectl() {
      local arg request_timeout=0 elapsed remaining cost=17
      elapsed=$(command cat "$MOCK_STATE/elapsed")
      for arg in "$@"; do
        case "$arg" in
          --request-timeout=*) request_timeout=${arg#*=}; request_timeout=${request_timeout%s} ;;
        esac
      done
      printf '%s %s\n' "$elapsed" "$request_timeout" >> "$MOCK_STATE/api-requests"
      if [[ "$probe" == api-elapsed-time && " $* " == *" get release "* ]]; then
        remaining=$((3600 - elapsed))
        if ((request_timeout > 0 && request_timeout < cost)); then
          cost=$request_timeout
          printf '%s\n' "$((elapsed + cost))" > "$MOCK_STATE/elapsed"
          touch "$MOCK_STATE/stalled-request-timed-out"
          printf 'Candidate Release API request timed out after %s seconds\n' "$cost" >&2
          return 1
        fi
        ((request_timeout == 0 || request_timeout <= remaining)) || touch "$MOCK_STATE/oversized-timeout"
        printf '%s\n' "$((elapsed + cost))" > "$MOCK_STATE/elapsed"
      fi
      fixture_kubectl "$@"
    }
    # shellcheck source=/dev/null
    source "$ARTIFACTS/production-script.sh"
  ) > "$ARTIFACTS/$probe.log" 2>&1
  actual_exit=$?
  set -e
  state=$(command cat "$ARTIFACTS/$probe-state")
  valid=true
  [[ "$actual_exit" == 1 && ! -f "$state/error" ]] || valid=false
  case "$probe" in
    newline-application | newline-component | newline-revision | newline-sha)
      [[ ! -f "$state/created.json" ]] || valid=false
      case "$probe" in
        newline-application | newline-component)
          grep -Eiq 'unsupported.*(application|component)' "$ARTIFACTS/$probe.log" || valid=false
          ;;
        *) grep -Eiq '(revision|sha).*(40|full|invalid|malformed)' "$ARTIFACTS/$probe.log" || valid=false ;;
      esac
      ;;
    newline-terminal-status | poll-after-deadline | api-elapsed-time)
      [[ ! -f "$state/created.json" && -f "$state/pending" && ! -f "$state/oversized-timeout" ]] || valid=false
      while read -r elapsed request_timeout; do
        ((elapsed < 3600 && request_timeout > 0 && request_timeout <= 30 &&
          request_timeout <= 3600 - elapsed)) || valid=false
      done < "$state/api-requests"
      [[ "$(command cat "$state/elapsed")" == 3600 ]] || valid=false
      grep -Eiq '(timed out|timeout).*Release|Release.*(timed out|timeout)' "$ARTIFACTS/$probe.log" || valid=false
      if [[ "$probe" == api-elapsed-time ]]; then
        [[ -f "$state/stalled-request-timed-out" ]] || valid=false
        grep -q '^3584 16$' "$state/api-requests" || valid=false
      fi
      ;;
  esac
  if $valid; then
    printf 'PASS: %s rejects safely with verified production effects\n' "$probe"
  else
    printf 'FAIL: %s did not satisfy rejection/deadline assertions (Task exit %s)\n' "$probe" "$actual_exit"
    failures=$((failures + 1))
  fi
done
if [[ "$(yq '.spec.steps[0].timeout' "$TASK_PATH")" == 1h ]]; then
  printf 'PASS: fixed Tekton step timeout is 1h\n'
else
  printf 'FAIL: fixed Tekton 1h execution backstop is missing\n'
  failures=$((failures + 1))
fi
printf 'Regression artifacts: %s\n' "$ARTIFACTS"
if ((failures > 0)); then
  printf 'Focused regression failures: %s\n' "$failures"
  exit 1
fi
