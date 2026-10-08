#!/usr/bin/env bash

# API fixtures mirror SnapshotSpec/ComponentSource in application-api and
# ReleaseSpec/ReleaseStatus in release-service. No kubectl call reaches a cluster.
# The Task's only input stays SNAPSHOT; the hook selects fixtures through this
# test-only environment variable and never substitutes production validation.
MOCK_STATE=$(mktemp -d)
export MOCK_STATE
printf '0\n' > "$MOCK_STATE/elapsed"

mock_error() {
  printf '%s\n' "$*" >&2
  touch "$MOCK_STATE/error"
  return 1
}

# Focused regression suite for this test utility; not invoked by an injected Task.
mock_self_test() {
  set +e
  local failures=0 task_exit scenario diagnostic
  PR_CANDIDATE_TEST_CASE=reject-non-pr
  MOCK_STATE=$(mktemp -d)
  kubectl -n default get snapshot reject-non-pr -o json > /dev/null
  (set -e; command pr_candidate_deliberately_missing_command) 2> "$MOCK_STATE/task-stderr"
  task_exit=$?
  if assert_task_outcome "$task_exit" > "$MOCK_STATE/assertion-output" 2>&1; then
    printf 'PASS: command-not-found after Snapshot read is rejected\n'
  else
    printf 'FAIL: command-not-found exit %s was accepted as intended rejection\n' "$task_exit"
    failures=$((failures + 1))
  fi

  MOCK_STATE=$(mktemp -d)
  jq() { return 73; }
  kubectl -n default get snapshot reject-non-pr -o json > /dev/null 2> "$MOCK_STATE/task-stderr"
  task_exit=$?
  unset -f jq
  if assert_task_outcome "$task_exit" > "$MOCK_STATE/assertion-output" 2>&1; then
    printf 'PASS: Snapshot fixture generation failure is rejected\n'
  else
    printf 'FAIL: fixture jq exit %s was accepted as intended rejection\n' "$task_exit"
    failures=$((failures + 1))
  fi
  if [[ -f "$MOCK_STATE/error" && ! -f "$MOCK_STATE/snapshot-read" ]]; then
    printf 'PASS: failed Snapshot generation records error without a read marker\n'
  else
    printf 'FAIL: failed Snapshot generation left incorrect markers\n'
    failures=$((failures + 1))
  fi

  for scenario in release-failure timeout-idempotency; do
    PR_CANDIDATE_TEST_CASE="$scenario"
    MOCK_STATE=$(mktemp -d)
    touch "$MOCK_STATE/created"
    jq() { return 73; }
    if [[ "$scenario" == release-failure ]]; then
      kubectl -n default get release pr-candidate-test -o json > /dev/null 2> "$MOCK_STATE/task-stderr"
    else
      kubectl -n default get releases -o json -l \
        'gcp-hcp.openshift.io/pr-candidate-snapshot-uid=11111111-2222-4333-8444-555555555555,gcp-hcp.openshift.io/pr-candidate-release-plan=gecko-controllers-pr-candidate' \
        > /dev/null 2> "$MOCK_STATE/task-stderr"
    fi
    unset -f jq
    if [[ -f "$MOCK_STATE/error" && ! -f "$MOCK_STATE/release-read" &&
      ! -f "$MOCK_STATE/terminal-failure" && ! -f "$MOCK_STATE/release-listed" ]]; then
      printf 'PASS: failed %s fixture generation leaves no read/status markers\n' "$scenario"
    else
      printf 'FAIL: failed %s fixture generation left incorrect markers\n' "$scenario"
      failures=$((failures + 1))
    fi
  done

  for scenario in reject-non-pr reject-unmapped-component reject-malformed-sha release-failure timeout-idempotency; do
    PR_CANDIDATE_TEST_CASE="$scenario"
    MOCK_STATE=$(mktemp -d)
    kubectl -n default get snapshot "$scenario" -o json > /dev/null
    case "$scenario" in
      reject-non-pr) diagnostic='Snapshot must be from a pull_request event' ;;
      reject-unmapped-component) diagnostic='Unsupported application/component pair' ;;
      reject-malformed-sha) diagnostic='Snapshot source revision must be a full lowercase 40-character hexadecimal SHA' ;;
      release-failure)
        touch "$MOCK_STATE/created"
        kubectl -n default get release pr-candidate-test -o json > /dev/null
        diagnostic='Candidate Release failed: ManagedPipelineProcessed=False'
        ;;
      timeout-idempotency)
        touch "$MOCK_STATE/release-listed"
        kubectl -n default get release pr-candidate-test -o json > /dev/null
        printf '3600\n' > "$MOCK_STATE/elapsed"
        diagnostic='Timed out waiting for candidate Release after 3600 seconds'
        ;;
    esac
    : > "$MOCK_STATE/task-stderr"
    if assert_task_outcome 1 > "$MOCK_STATE/assertion-output" 2>&1; then
      printf 'PASS: %s without its diagnostic is rejected\n' "$scenario"
    else
      printf 'FAIL: %s without its diagnostic was accepted\n' "$scenario"
      failures=$((failures + 1))
    fi
    printf 'Unrelated helper failure\n' > "$MOCK_STATE/task-stderr"
    if assert_task_outcome 1 > "$MOCK_STATE/assertion-output" 2>&1; then
      printf 'PASS: %s with an unrelated diagnostic is rejected\n' "$scenario"
    else
      printf 'FAIL: %s with an unrelated diagnostic was accepted\n' "$scenario"
      failures=$((failures + 1))
    fi
    printf '%s\n' "$diagnostic" > "$MOCK_STATE/task-stderr"
    if assert_task_outcome 1 > "$MOCK_STATE/assertion-output" 2>&1; then
      printf 'FAIL: intended %s failure was rejected\n' "$scenario"
      failures=$((failures + 1))
    else
      printf 'PASS: intended %s failure is recognized\n' "$scenario"
    fi
  done
  if ((failures > 0)); then
    printf 'Focused regression failures: %s\n' "$failures"
    return 1
  fi
}

mock_snapshot() {
  local event=pull_request application=gecko-controllers component=gecko-controllers
  local revision=0123456789abcdef0123456789abcdef01234567
  case "$PR_CANDIDATE_TEST_CASE" in
    success | success-idempotency | release-failure | timeout-idempotency) ;;
    success-platform-api)
      application=gecko-platform-api-server
      component=gecko-platform-api-server
      ;;
    reject-non-pr) event=push ;;
    reject-unmapped-component) component=gecko-platform-api-server ;;
    reject-malformed-sha) revision=0123456789abcdef0123456789abcdef0123456 ;;
    *) mock_error "Unknown Snapshot fixture"; return 1 ;;
  esac
  jq -n --arg name "$PR_CANDIDATE_TEST_CASE" --arg event "$event" \
    --arg application "$application" --arg component "$component" --arg revision "$revision" '
    {
      apiVersion: "appstudio.redhat.com/v1alpha1", kind: "Snapshot",
      metadata: {
        name: $name, namespace: "default", uid: "11111111-2222-4333-8444-555555555555",
        resourceVersion: "1", generation: 1, creationTimestamp: "2026-10-08T12:00:00Z",
        labels: {
          "pac.test.appstudio.openshift.io/event-type": $event,
          "pac.test.appstudio.openshift.io/sha": $revision,
          "appstudio.openshift.io/application": $application
        }
      },
      spec: {
        application: $application, artifacts: {},
        components: [{
          name: $component,
          containerImage: ("quay.io/example/" + $component +
            "@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
          source: {git: {url: "https://github.com/openshift-online/gecko", revision: $revision}}
        }]
      },
      status: {conditions: []}
    }' || mock_error "Snapshot fixture generation failed"
}

mock_expected_plan() {
  local plan
  case "$PR_CANDIDATE_TEST_CASE" in
    success-platform-api) plan=gecko-platform-api-server-pr-candidate ;;
    *) plan=gecko-controllers-pr-candidate ;;
  esac
  printf '%s\n' "$plan" || mock_error "ReleasePlan fixture generation failed"
}

mock_release() {
  local status="$1" reason=Progressing message="Candidate copy is running" plan
  case "$status" in
    True) reason=Succeeded; message="Candidate copy completed" ;;
    False) reason=Failed; message="Candidate copy failed" ;;
  esac
  plan=$(mock_expected_plan) || { mock_error "ReleasePlan fixture generation failed"; return 1; }
  jq -n --arg snapshot "$PR_CANDIDATE_TEST_CASE" --arg plan "$plan" \
    --arg status "$status" --arg reason "$reason" --arg message "$message" '
    {
      apiVersion: "appstudio.redhat.com/v1alpha1", kind: "Release",
      metadata: {
        name: "pr-candidate-test", generateName: "pr-candidate-", namespace: "default",
        uid: "66666666-7777-4888-8999-000000000000", resourceVersion: "2", generation: 1,
        creationTimestamp: "2026-10-08T12:01:00Z",
        labels: {
          "gcp-hcp.openshift.io/pr-candidate-snapshot-uid": "11111111-2222-4333-8444-555555555555",
          "gcp-hcp.openshift.io/pr-candidate-release-plan": $plan
        }
      },
      spec: {snapshot: $snapshot, releasePlan: $plan},
      status: {
        automated: false,
        conditions: [
          {type: "Validated", status: "True", reason: "Succeeded", message: "Release validation passed",
            lastTransitionTime: "2026-10-08T12:01:00Z", observedGeneration: 1},
          {type: "ManagedPipelineProcessed", status: $status, reason: $reason, message: $message,
            lastTransitionTime: "2026-10-08T12:01:00Z", observedGeneration: 1}
        ]
      }
    }' || mock_error "Release fixture generation failed"
}

mock_release_list() {
  local release condition
  case "$PR_CANDIDATE_TEST_CASE" in
    success-idempotency) condition=True ;;
    timeout-idempotency) condition=Unknown ;;
    *)
      printf '%s\n' '{"apiVersion":"appstudio.redhat.com/v1alpha1","kind":"ReleaseList",
        "metadata":{"resourceVersion":"2"},"items":[]}' || mock_error "ReleaseList fixture generation failed"
      return
      ;;
  esac
  release=$(mock_release "$condition") || { mock_error "ReleaseList item generation failed"; return 1; }
  jq -n --argjson release "$release" '{apiVersion: "appstudio.redhat.com/v1alpha1",
    kind: "ReleaseList", metadata: {resourceVersion: "2"}, items: [$release]}' ||
    mock_error "ReleaseList fixture generation failed"
}

kubectl() {
  local namespace="" output="" selector="" filename="" verb="" resource="" name="" response=""
  while (($#)); do
    case "$1" in
      -n | --namespace) namespace="$2"; shift 2 ;;
      --namespace=*) namespace="${1#*=}"; shift ;;
      -o | --output) output="$2"; shift 2 ;;
      --output=* | -o=*) output="${1#*=}"; shift ;;
      -l | --selector) selector="$2"; shift 2 ;;
      --selector=*) selector="${1#*=}"; shift ;;
      -f | --filename) filename="$2"; shift 2 ;;
      --filename=*) filename="${1#*=}"; shift ;;
      -*) mock_error "Unexpected kubectl option: $1"; return 1 ;;
      *)
        if [[ -z "$verb" ]]; then verb="$1"
        elif [[ -z "$resource" ]]; then resource="$1"
        elif [[ -z "$name" ]]; then name="$1"
        else mock_error "Unexpected kubectl argument: $1"; return 1
        fi
        shift
        ;;
    esac
  done
  if [[ "$namespace" != default ]]; then
    mock_error "Task must use its own namespace (default in the test harness)"
    return 1
  fi
  case "$verb/$resource" in
    get/snapshot | get/snapshots | get/snapshot.appstudio.redhat.com)
      if [[ "$name" != "$PR_CANDIDATE_TEST_CASE" || "$output" != json ]]; then
        mock_error "Expected named Snapshot read as JSON"; return 1
      fi
      response=$(mock_snapshot) || { mock_error "Snapshot read fixture failed"; return 1; }
      printf '%s\n' "$response" || { mock_error "Snapshot fixture output failed"; return 1; }
      touch "$MOCK_STATE/snapshot-read"
      ;;
    get/release | get/releases | get/releases.appstudio.redhat.com)
      if [[ "$output" != json ]]; then mock_error "Expected Release JSON read"; return 1; fi
      if [[ -n "$selector" && -z "$name" ]]; then
        local uid_label='gcp-hcp.openshift.io/pr-candidate-snapshot-uid=11111111-2222-4333-8444-555555555555'
        local plan_label plan
        plan=$(mock_expected_plan) || { mock_error "ReleasePlan fixture generation failed"; return 1; }
        plan_label="gcp-hcp.openshift.io/pr-candidate-release-plan=$plan"
        if [[ "$selector" != "$uid_label,$plan_label" && "$selector" != "$plan_label,$uid_label" ]]; then
          mock_error "Release lookup must use both idempotency labels"; return 1
        fi
        response=$(mock_release_list) || { mock_error "Release list fixture failed"; return 1; }
        printf '%s\n' "$response" || { mock_error "ReleaseList fixture output failed"; return 1; }
        touch "$MOCK_STATE/release-listed"
      elif [[ "$name" == pr-candidate-test && -z "$selector" ]]; then
        if [[ ! -f "$MOCK_STATE/created" && ! -f "$MOCK_STATE/release-listed" ]]; then
          mock_error "Release read before create or lookup"; return 1
        fi
        local condition
        case "$PR_CANDIDATE_TEST_CASE" in
          release-failure) condition=False ;;
          timeout-idempotency) condition=Unknown ;;
          *) condition=True ;;
        esac
        response=$(mock_release "$condition") || { mock_error "Release read fixture failed"; return 1; }
        printf '%s\n' "$response" || { mock_error "Release fixture output failed"; return 1; }
        touch "$MOCK_STATE/release-read"
        case "$PR_CANDIDATE_TEST_CASE" in
          release-failure) touch "$MOCK_STATE/terminal-failure" ;;
          timeout-idempotency) touch "$MOCK_STATE/pending" ;;
        esac
      else
        mock_error "Unexpected Release lookup"; return 1
      fi
      ;;
    create/)
      if [[ "$filename" != - || "$output" != name || -n "$name" ]]; then
        mock_error "Expected kubectl create -f - -o name"; return 1
      fi
      if [[ -f "$MOCK_STATE/created" || "$PR_CANDIDATE_TEST_CASE" == *idempotency ]]; then
        mock_error "Task created a duplicate Release"; return 1
      fi
      # Capture the real Task's emitted API payload; jq and validation stay real.
      command cat > "$MOCK_STATE/created.json" || { mock_error "Release payload capture failed"; return 1; }
      local plan
      plan=$(mock_expected_plan) || { mock_error "ReleasePlan fixture generation failed"; return 1; }
      if ! jq -e --arg snapshot "$PR_CANDIDATE_TEST_CASE" --arg plan "$plan" '
        .apiVersion == "appstudio.redhat.com/v1alpha1" and .kind == "Release" and
        .metadata.generateName == "pr-candidate-" and
        .metadata.labels["gcp-hcp.openshift.io/pr-candidate-snapshot-uid"] ==
          "11111111-2222-4333-8444-555555555555" and
        .metadata.labels["gcp-hcp.openshift.io/pr-candidate-release-plan"] == $plan and
        .spec == {snapshot: $snapshot, releasePlan: $plan}
      ' "$MOCK_STATE/created.json" > /dev/null; then
        mock_error "Task emitted an incorrect Release payload"; return 1
      fi
      touch "$MOCK_STATE/created"
      printf 'release.appstudio.redhat.com/pr-candidate-test\n' || mock_error "Created Release output failed"
      ;;
    *) mock_error "Unexpected kubectl API operation: $verb/$resource"; return 1 ;;
  esac
}

# Advance wall time without spending an hour in the timeout test.
date() {
  if [[ "$*" != +%s ]]; then mock_error "Unexpected date call"; return 1; fi
  local elapsed
  elapsed=$(command cat "$MOCK_STATE/elapsed")
  printf '%s\n' "$((1791451200 + elapsed))"
}

sleep() {
  if [[ "$*" != 15 ]]; then mock_error "Polling must wait 15 seconds"; return 1; fi
  if [[ "$PR_CANDIDATE_TEST_CASE" == release-failure && -f "$MOCK_STATE/terminal-failure" ]]; then
    mock_error "Task continued polling after terminal failure"; return 1
  fi
  local elapsed
  elapsed=$(command cat "$MOCK_STATE/elapsed")
  if ((elapsed >= 3600)); then mock_error "Polling exceeded 3600 seconds"; return 1; fi
  printf '%s\n' "$((elapsed + 15))" > "$MOCK_STATE/elapsed"
}

assert_task_outcome() {
  local task_exit="$1" valid=true expected_failure=false
  [[ -f "$MOCK_STATE/snapshot-read" && ! -f "$MOCK_STATE/error" ]] || valid=false
  case "$PR_CANDIDATE_TEST_CASE" in
    success | success-platform-api)
      [[ -f "$MOCK_STATE/created" && -f "$MOCK_STATE/release-read" ]] || valid=false
      ;;
    success-idempotency)
      [[ -f "$MOCK_STATE/release-listed" && -f "$MOCK_STATE/release-read" &&
        ! -f "$MOCK_STATE/created" ]] || valid=false
      ;;
    reject-*)
      expected_failure=true
      [[ ! -f "$MOCK_STATE/created.json" && ! -f "$MOCK_STATE/release-read" ]] || valid=false
      ;;
    release-failure)
      expected_failure=true
      [[ -f "$MOCK_STATE/created" && -f "$MOCK_STATE/terminal-failure" ]] || valid=false
      ;;
    timeout-idempotency)
      expected_failure=true
      [[ -f "$MOCK_STATE/release-listed" && -f "$MOCK_STATE/pending" &&
        ! -f "$MOCK_STATE/created.json" ]] || valid=false
      [[ "$(command cat "$MOCK_STATE/elapsed")" == 3600 ]] || valid=false
      ;;
    *) valid=false ;;
  esac
  if $expected_failure; then
    # Require a useful diagnostic from the real script for the specific failure.
    # Runtime exits (e.g. 127) and unrelated fixture errors must never satisfy it.
    local diagnostic
    case "$PR_CANDIDATE_TEST_CASE" in
      reject-non-pr) diagnostic='pull_request.*(event|provenance)|(event|provenance).*pull_request' ;;
      reject-unmapped-component) diagnostic='(unsupported|unmapped).*(application|component)' ;;
      reject-malformed-sha) diagnostic='(revision|sha).*(40|full|invalid|malformed)|(40|full).*(revision|sha)' ;;
      release-failure) diagnostic='ManagedPipelineProcessed.*False|candidate Release.*failed' ;;
      timeout-idempotency) diagnostic='(timed out|timeout).*Release|Release.*(timed out|timeout)' ;;
    esac
    [[ -f "$MOCK_STATE/task-stderr" ]] || valid=false
    grep -Eiq "$diagnostic" "$MOCK_STATE/task-stderr" 2> /dev/null || valid=false
    if $valid && ((task_exit == 1)); then
      printf 'Observed expected Task rejection/failure with verified API effects\n'
      return 1
    fi
    # The catalog harness expects this Task to fail. Return success for an
    # unexpected error so a broken mock/setup cannot pass a negative test.
    printf 'Expected failure assertions were not satisfied (Task exit %s)\n' "$task_exit" >&2
    return 0
  fi
  if $valid && ((task_exit == 0)); then
    printf 'Verified mapped candidate Release and successful completion\n'
    return 0
  fi
  printf 'Candidate success assertions were not satisfied (Task exit %s)\n' "$task_exit" >&2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "$0" && "${1:-}" == --self-test ]]; then
  mock_self_test
fi
