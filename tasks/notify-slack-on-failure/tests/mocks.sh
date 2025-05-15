#!/usr/bin/env bash

# SC2016 - "Expressions don't expand in single quotes, use double quotes for that." 
# is disabled because line 26 is checking for backticks, so single quotes are being
# used to prevent ```SAMPLE ERROR MESSAGE``` from being expanded

# shellcheck disable=SC2016
set -eux

# mocks to be injected into task step scripts

function curl() {
  echo Mock curl called with: $*
  echo $* >> /tmp/mock_curl.txt

  if [[ "$*" != "-H Content-type: application/json --data-binary @/tmp/payload.json ABCDEF"* ]]
  then
    echo Error: Unexpected call
    exit 1
  fi

  # no workspaces to pass information along, but there's only one test that actually uses curl.
  # if any other test manages to use curl, release is set to 'ns/success' in all other tests
  # so they won't reproduce the error message and the test will fail
  if [ "$(cat /tmp/payload.json)" != \
    '{"text": "Managed pipelines failed: ```SAMPLE ERROR MESSAGE```"}' ]; then
    echo Error: unexpected message
    cat /tmp/payload.json
    exit 1
  fi

  # makes sure curl is not called multiple times on test-notify-slack-release-failure.yaml
  if [ "$(wc -l < /tmp/mock_curl.txt)" != 1 ]; then
    echo Error: curl was expected to be called 1 times. Actual calls:
    cat /tmp/mock_curl.txt
    exit 1
  fi
}

function kubectl() {
  if [[ "$*" == *"release"* ]]
  then
    if [[ "$*" == *fail* ]]
    then
      cat > /tmp/mock-release.json <<EOF
      {
      "apiVersion": "appstudio.redhat.com/v1alpha1",
      "kind": "Release",
      "metadata": {
          "name": "my-release"
      },
      "status": {
          "conditions": [
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "Validated"
          },
          {
              "message": "",
              "reason": "Skipped",
              "status": "True",
              "type": "TenantCollectorsPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Skipped",
              "status": "True",
              "type": "ManagedCollectorsPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "ManagedPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "TenantPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "ManagedPipelineProcessed"
          },
          {
              "message": "SAMPLE ERROR MESSAGE",
              "reason": "Failed",
              "status": "False",
              "type": "ManagedPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "ManagedPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Progressing",
              "status": "False",
              "type": "FinalPipelineProcessed"
          }
          ]
      }
      }
EOF

    elif [[ "$*" == *success* ]]
    then
      cat > /tmp/mock-release.json <<EOF
      {
      "apiVersion": "appstudio.redhat.com/v1alpha1",
      "kind": "Release",
      "metadata": {
          "name": "my-release"
      },
      "status": {
          "conditions": [
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "Validated"
          },
          {
              "message": "",
              "reason": "Skipped",
              "status": "True",
              "type": "TenantCollectorsPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Skipped",
              "status": "True",
              "type": "ManagedCollectorsPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "ManagedPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "TenantPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "ManagedPipelineProcessed"
          },
          {
              "message": "",
              "reason": "Progressing",
              "status": "False",
              "type": "FinalPipelineProcessed"
          }
          ]
      }
      }
EOF
    fi
  fi

  if [[ "$*" == *"-o jsonpath={.status.conditions}"* ]]; then
    cat /tmp/mock-release.json | jq .status.conditions
  else
    cat /tmp/mock-release.json
  fi

}
