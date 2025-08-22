#!/usr/bin/env bash

set -eux

# mocks to be injected into task step scripts


function kubectl() {
  if [[ "$*" == *"snapshot"* ]]; then
    if [[ "$3" == "nopermission" ]]; then
      TEST_IMAGE="quay.io/no-permission:tag"
    elif [[ "$3" == "skip-image" ]]; then
      TEST_IMAGE="quay.io/valid-repo:skip-image"
    else
      TEST_IMAGE="quay.io/valid-repo:tag"
    fi

    EXTRA_COMPONENTS=""
    if [[ "$3" == "multiple" ]]; then
      EXTRA_COMPONENTS=',
      {
        "containerImage": "quay.io/valid-repo:tag2",
        "name": "test-image2"
      },
      {
        "containerImage": "quay.io/valid-repo:skip-image",
        "name": "test-image3"
      },
      {
        "containerImage": "quay.io/valid-repo2:skip-image",
        "name": "test-image4"
      }'
    fi

    if [[ "$3" == "empty" ]]; then
      cat > /tmp/mock-snapshot.json <<EOF
      {
        "apiVersion": "appstudio.redhat.com/v1alpha1",
        "kind": "Snapshot",
        "metadata": {
          "name": "snapshot",
          "namespace": "ns2"
        },
        "spec": {
          "application": "demo",
          "artifacts": {},
          "components": []
        }
      }
EOF
    else
      cat > /tmp/mock-snapshot.json <<EOF
      {
        "apiVersion": "appstudio.redhat.com/v1alpha1",
        "kind": "Snapshot",
        "metadata": {
          "name": "snapshot",
          "namespace": "ns2"
        },
        "spec": {
          "application": "demo",
          "artifacts": {},
          "components": [
            {
              "containerImage": "$TEST_IMAGE",
              "name": "test-image"
            }$EXTRA_COMPONENTS
          ]
        }
      }
EOF
    fi

    if [[ "$*" == *"jsonpath={.spec}"* ]]; then
      cat /tmp/mock-snapshot.json | jq .spec
    else
      cat /tmp/mock-snapshot.json
    fi

  elif [[ "$*" == *"releaseplan"* ]]
  then
    if [[ "$3" == "skip-image" ]]; then
      TEST_REPO="quay.io/valid-repo2"
    else
      TEST_REPO="quay.io/default-repo2"
    fi

    EXTRA_COMPONENT_DESTINATIONS=""
    if [[ "$3" == "multiple" ]]; then
      EXTRA_COMPONENT_DESTINATIONS=',
      {
        "name": "test-image2",
        "repository": "quay.io/default-repo3",
        "tags": [
          "testtag",
          "testtag2"
        ]
      },
      {
        "name": "test-image3",
        "repository": "quay.io/default-repo2",
        "tags": [
          "skip-image"
        ]
      },
      {
        "name": "test-image4",
        "repository": "quay.io/default-repo2",
        "tags": [
          "skip-image",
          "testtag"
        ]
      }'
    fi

    cat > /tmp/mock-releaseplan.json <<EOF
    {
      "apiVersion": "appstudio.redhat.com/v1alpha1",
      "kind": "ReleasePlan",
      "metadata": {
        "name": "releaseplan",
        "namespace": "ns2"
      },
      "spec": {
        "application": "demo",
        "data": {
          "mapping": {
            "components": [
              {
                "name": "test-image",
                "repository": "$TEST_REPO",
                "tags": [
                  "testtag"
                ]
              }$EXTRA_COMPONENT_DESTINATIONS
            ]
          }
        }
      }
    }
EOF

    if [[ "$*" == *"jsonpath={.spec.data.mapping}"* ]]; then
      cat /tmp/mock-releaseplan.json | jq .spec.data.mapping
    else
      cat /tmp/mock-releaseplan.json
    fi
  elif [[ "$*" == *"release "* ]]
  then
    # Simulate release status for release lookups
    RELEASE_NAMESPACE="$2"
    RELEASE_NAME="$3"
    if [[ "$3" == "fail" ]]; then
      cat > /tmp/mock-release.json <<EOF
      {
        "apiVersion": "appstudio.redhat.com/v1alpha1",
        "kind": "Release",
        "metadata": {
          "name": "fail",
          "namespace": "$2"
        },
        "status": {
          "conditions": [
            {
              "message": "Simulated failure message",
              "reason": "Failed",
              "status": "False",
              "type": "ManagedPipelineProcessed"
            }
          ]
        }
      }
EOF
    elif [[ "$3" == "success" ]]; then
      cat > /tmp/mock-release.json <<EOF
      {
        "apiVersion": "appstudio.redhat.com/v1alpha1",
        "kind": "Release",
        "metadata": {
          "name": "success",
          "namespace": "$2"
        },
        "status": {
          "conditions": [
            {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "ManagedPipelineProcessed"
            }
          ]
        }
      }
EOF
    else
      cat > /tmp/mock-release.json <<EOF
      {
        "apiVersion": "appstudio.redhat.com/v1alpha1",
        "kind": "Release",
        "metadata": {
          "name": "$3",
          "namespace": "$2"
        },
        "status": {
          "conditions": [
            {
              "message": "",
              "reason": "Succeeded",
              "status": "True",
              "type": "ManagedPipelineProcessed"
            }
          ]
        }
      }
EOF
    fi
    if [[ "$*" == *"jsonpath={.status.conditions}"* ]]; then
      cat /tmp/mock-release.json | jq '.status.conditions'
    else
      cat /tmp/mock-release.json
    fi
  fi

}
# This file must have a newline at the end of it because of how we concatenate
# the mocks into the task steps.
