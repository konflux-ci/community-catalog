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
    }'
}

mock_expected_plan() {
  case "$PR_CANDIDATE_TEST_CASE" in
    success-platform-api) printf 'gecko-platform-api-server-pr-candidate\n' ;;
    *) printf 'gecko-controllers-pr-candidate\n' ;;
  esac
}

mock_release() {
  local status="$1" reason=Progressing message="Candidate copy is running"
  case "$status" in
    True) reason=Succeeded; message="Candidate copy completed" ;;
    False) reason=Failed; message="Candidate copy failed" ;;
  esac
  jq -n --arg snapshot "$PR_CANDIDATE_TEST_CASE" --arg plan "$(mock_expected_plan)" \
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
    }'
}

kubectl() {
  local namespace="" output="" selector="" filename="" verb="" resource="" name=""
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
      touch "$MOCK_STATE/snapshot-read"
      mock_snapshot
      ;;
    get/release | get/releases | get/releases.appstudio.redhat.com)
      if [[ "$output" != json ]]; then mock_error "Expected Release JSON read"; return 1; fi
      if [[ -n "$selector" && -z "$name" ]]; then
        local uid_label='gcp-hcp.openshift.io/pr-candidate-snapshot-uid=11111111-2222-4333-8444-555555555555'
        local plan_label
        plan_label="gcp-hcp.openshift.io/pr-candidate-release-plan=$(mock_expected_plan)"
        if [[ "$selector" != "$uid_label,$plan_label" && "$selector" != "$plan_label,$uid_label" ]]; then
          mock_error "Release lookup must use both idempotency labels"; return 1
        fi
        touch "$MOCK_STATE/release-listed"
        case "$PR_CANDIDATE_TEST_CASE" in
          success-idempotency) mock_release True | jq '{apiVersion: "appstudio.redhat.com/v1alpha1",
            kind: "ReleaseList", metadata: {resourceVersion: "2"}, items: [.]}' ;;
          timeout-idempotency) mock_release Unknown | jq '{apiVersion: "appstudio.redhat.com/v1alpha1",
            kind: "ReleaseList", metadata: {resourceVersion: "2"}, items: [.]}' ;;
          *) printf '%s\n' '{"apiVersion":"appstudio.redhat.com/v1alpha1","kind":"ReleaseList",
            "metadata":{"resourceVersion":"2"},"items":[]}' ;;
        esac
      elif [[ "$name" == pr-candidate-test && -z "$selector" ]]; then
        if [[ ! -f "$MOCK_STATE/created" && ! -f "$MOCK_STATE/release-listed" ]]; then
          mock_error "Release read before create or lookup"; return 1
        fi
        touch "$MOCK_STATE/release-read"
        case "$PR_CANDIDATE_TEST_CASE" in
          release-failure) touch "$MOCK_STATE/terminal-failure"; mock_release False ;;
          timeout-idempotency) touch "$MOCK_STATE/pending"; mock_release Unknown ;;
          *) mock_release True ;;
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
      command cat > "$MOCK_STATE/created.json"
      if ! jq -e --arg snapshot "$PR_CANDIDATE_TEST_CASE" --arg plan "$(mock_expected_plan)" '
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
      printf 'release.appstudio.redhat.com/pr-candidate-test\n'
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
    if $valid && ((task_exit != 0)); then
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
