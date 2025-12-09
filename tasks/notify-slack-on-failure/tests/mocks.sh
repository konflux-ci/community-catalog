#!/usr/bin/env bash

# SC2016 - "Expressions don't expand in single quotes, use double quotes for that."
# is disabled because line 26 is checking for backticks, so single quotes are being
# used to prevent ```SAMPLE ERROR MESSAGE``` from being expanded

# shellcheck disable=SC2016
set -eux

# mocks to be injected into task step scripts

function curl() {
  echo Mock curl called with: "$*"
  echo "$*" >> /tmp/mock_curl.txt

  if [[ "$*" != "-H Content-type: application/json --data-binary @/tmp/payload.json ABCDEF"* ]]
  then
    echo Error: Unexpected call
    exit 1
  fi

  # Extract the actual message text from the JSON payload
  # We distinguish test cases by the message content (release namespace/name and presence of mentions)
  ACTUAL_TEXT=$(cat /tmp/payload.json | jq -r '.text')

  # Check for mentions and message content once - we'll verify them based on the test case
  HAS_UFAIL1=$(echo "$ACTUAL_TEXT" | grep -c "<@Ufail1>" || true)
  HAS_UFAIL2=$(echo "$ACTUAL_TEXT" | grep -c "<@Ufail2>" || true)
  HAS_UFAIL3=$(echo "$ACTUAL_TEXT" | grep -c "<@Ufail3>" || true)
  HAS_SFAIL1=$(echo "$ACTUAL_TEXT" | grep -c "<!subteam^Sfail1>" || true)
  HAS_USUCCESS1=$(echo "$ACTUAL_TEXT" | grep -c "<@Usuccess1>" || true)
  HAS_USUCCESS2=$(echo "$ACTUAL_TEXT" | grep -c "<@Usuccess2>" || true)
  HAS_FAILURE=$(echo "$ACTUAL_TEXT" | grep -c "SAMPLE ERROR MESSAGE" || true)
  HAS_SUCCESS=$(echo "$ACTUAL_TEXT" | grep -c "Managed pipelines succeeded" || true)

  # Check for message format with release namespace/name:
  # Each test uses a unique release name matching the test case
  if echo "$ACTUAL_TEXT" | grep -q "Release: ns/release-failure" && [ "$HAS_FAILURE" -eq 0 ]; then
    echo Error: unexpected message
    echo Actual text: "$ACTUAL_TEXT"
    exit 1
  fi

  # Distinguish between failure test cases by release name
  if echo "$ACTUAL_TEXT" | grep -q "Release: ns/release-failure-no-mentions"; then
    # This test should have NO mentions
    if [ "$HAS_UFAIL1" -gt 0 ] || [ "$HAS_UFAIL2" -gt 0 ] || [ "$HAS_UFAIL3" -gt 0 ] || [ "$HAS_SFAIL1" -gt 0 ]; then
      echo "Error: unexpected mentions found in failure message without mentions"
      echo Actual text: "$ACTUAL_TEXT"
      exit 1
    fi
  elif echo "$ACTUAL_TEXT" | grep -q "Release: ns/release-failure" && ! echo "$ACTUAL_TEXT" | grep -q "Release: ns/release-failure-no-mentions"; then
    # This is the release-failure test (with mentions), verify mentions are present
    if [ "$HAS_UFAIL1" -eq 0 ] || [ "$HAS_UFAIL2" -eq 0 ] || [ "$HAS_UFAIL3" -eq 0 ] || [ "$HAS_SFAIL1" -eq 0 ]; then
      echo "Error: expected mentions <@Ufail1>, <@Ufail2>, <@Ufail3>, and <!subteam^Sfail1> not found"
      echo Actual text: "$ACTUAL_TEXT"
      exit 1
    fi
  elif (echo "$ACTUAL_TEXT" | grep -q "Release: ns/release-success-with-notify" || echo "$ACTUAL_TEXT" | grep -q "Release: ns/success-mentions-no-tag") && [ "$HAS_SUCCESS" -eq 0 ]; then
    echo Error: unexpected message
    echo Actual text: "$ACTUAL_TEXT"
    exit 1
  elif echo "$ACTUAL_TEXT" | grep -q "Release: ns/release-success-with-notify" || echo "$ACTUAL_TEXT" | grep -q "Release: ns/success-mentions-no-tag"; then
    # Distinguish between success test cases by release name
    if echo "$ACTUAL_TEXT" | grep -q "Release: ns/release-success-with-notify"; then
      # This test has tagSuccess=true, mentions should be present
      if [ "$HAS_USUCCESS1" -eq 0 ] || [ "$HAS_USUCCESS2" -eq 0 ]; then
        echo "Error: expected mentions <@Usuccess1> and <@Usuccess2> not found in success message"
        echo Actual text: "$ACTUAL_TEXT"
        exit 1
      fi
    elif echo "$ACTUAL_TEXT" | grep -q "Release: ns/success-mentions-no-tag"; then
      # This test has tagSuccess=false, mentions should NOT be present
      if [ "$HAS_USUCCESS1" -gt 0 ] || [ "$HAS_USUCCESS2" -gt 0 ]; then
        echo "Error: unexpected mentions found in success message without tagSuccess"
        echo Actual text: "$ACTUAL_TEXT"
        exit 1
      fi
    fi
  else
    echo Error: unexpected message
    echo Actual text: "$ACTUAL_TEXT"
    exit 1
  fi

  # makes sure curl is not called multiple times
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
