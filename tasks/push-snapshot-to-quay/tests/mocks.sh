#!/usr/bin/env bash
set -eux

# mocks to be injected into task step scripts

function cosign() {
  # mock cosign failing for the no-permission test
  if [[ "$*" == "copy -f quay.io/no-permission:tag "*":"* ]]
  then
    echo Invalid credentials for quay.io/no-permission:tag
    return 1
  fi

  if [[ "$*" != "copy -f "*":"*" "*":"* ]]
  then
    echo Error: Unexpected call
    exit 1
  fi
}

function kubectl() {
  if [[ "$*" == *"snapshot"* ]]
  then
    if [[ "$3" == "nopermission" ]]; then
      TEST_IMAGE="quay.io/no-permission:tag"
    elif [[ "$3" == "skip-image" ]]; then
      TEST_IMAGE="quay.io/valid-repo:skip-image"
    else
      TEST_IMAGE="quay.io/valid-repo:tag"
    fi

    EXTRA_COMPONENTS=""
    GIT_SOURCE=""
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
    elif [[ "$3" == "templated" ]]; then
      GIT_SOURCE=',
      "source": {
        "git": {
          "revision": "abcdef1234567890abcdef1234567890abcdef12"
        }
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
              "name": "test-image"$GIT_SOURCE
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
    DEFAULTS_SECTION=""
    COMPONENT_TAGS='["testtag"]'
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
    elif [[ "$3" == "templated" ]]; then
      EXTRA_COMPONENT_DESTINATIONS=''
      COMPONENT_TAGS='[
        "{{ git_sha }}",
        "{{ timestamp }}",
        "{{ release_timestamp }}",
        "{{ labels.mylabel }}",
        "{{ incrementer }}",
        "v1.0.0-{{ git_short_sha }}"
      ]'
      DEFAULTS_SECTION=',
      "defaults": {
        "tags": [
          "{{ git_short_sha }}",
          "latest"
        ],
        "timestampFormat": "%Y%m%d"
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
                "tags": $COMPONENT_TAGS
              }$EXTRA_COMPONENT_DESTINATIONS
            ]$DEFAULTS_SECTION
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

function get-image-architectures() {
  cat <<EOF
[
  {
    "platform": {
      "architecture": "amd64",
      "os": "linux"
    }
  }
]
EOF
}

function skopeo() {
  if [[ "$*" == *"list-tags"* ]]; then
    cat <<EOF
{
  "Repository": "quay.io/default-repo2",
  "Tags": [
    "testtag-1",
    "testtag-2",
    "latest"
  ]
}
EOF
  elif [[ "$*" == *"inspect"* ]]; then
    cat <<EOF
{
  "Name": "quay.io/valid-repo:tag",
  "Created": "2023-01-01T00:00:00Z",
  "Labels": {
    "build-date": "2023-01-01T00:00:00Z",
    "mylabel": "myvalue"
  }
}
EOF
  else
    echo Mock skopeo called with: $*
    echo Error: Unexpected call
    exit 1
  fi
}

function date() {
  if [[ "$*" == *"+%Y%m%d %T"* ]]; then
    echo "20230101 00:00:00"
  elif [[ "$*" == *"+%Y%m%d"* ]]; then
    echo "20230101"
  elif [[ "$*" == *"+%s"* ]]; then
    echo "1672531200"
  else
    command date "$@"
  fi
}

function oras() {
  if [[ "$*" == "resolve --registry-config "*" "* ]]; then
    if [[ "$*" =~ "--platform" && "$4" =~ ".src" ]]; then
      echo "Error: .src images should not use --platform" >&2
      exit 1
    fi
    if [[ "$4" == *skip-image* ]]; then
      echo "sha256:111111"
    else
      # echo the shasum computed from the pull spec so the task knows if two images are the same
      echo -n "sha256:"
      echo $4 | sha256sum | cut -d ' ' -f 1
    fi
    return
  else
    echo Mock oras called with: $*
    echo Error: Unexpected call
    exit 1
  fi
}
