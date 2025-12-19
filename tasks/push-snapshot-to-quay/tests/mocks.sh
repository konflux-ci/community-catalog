#!/usr/bin/env bash
set -eux

# mocks to be injected into task step scripts

function cosign() {
  # mock cosign failing for the no-permission test
  if [[ "$1" == "copy" && "$2" == "-f" && "$3" == "quay.io/no-permission:tag" ]]
  then
    echo Invalid credentials for quay.io/no-permission:tag
    return 1
  fi

  # Accept valid cosign copy calls
  if [[ "$1" == "copy" && "$2" == "-f" && "$3" == *":"* && "$4" == *":"* ]]
  then
    return 0
  fi

  echo Error: Unexpected call
  exit 1
}

function skopeo() {
  # Mock skopeo for testing copyAllAttestations=false
  if [[ "$1" == "copy" && "$2" == "--all" && "$3" == docker://* && "$4" == docker://* ]]
  then
    echo "Skopeo copy executed (no attestations)"
    return 0
  fi

  # Mock skopeo inspect - return metadata based on image
  if [[ "$*" == *"inspect"* ]]; then
    if [[ "$*" == *"templating-test"* ]]; then
      # Return templating-specific metadata
      cat <<EOF
{
  "Labels": {
    "build-date": "2024-01-15T10:30:00Z",
    "version": "1.2.3"
  },
  "Created": "2024-01-15T10:30:00Z"
}
EOF
    else
      # Return default metadata
      cat <<EOF
{
  "Labels": {
    "build-date": "2024-01-01T10:30:00Z",
    "version": "1.0.0"
  },
  "Created": "2024-01-01T10:30:00Z"
}
EOF
    fi
    return 0
  fi

  # Mock skopeo list-tags - return tags based on repository
  if [[ "$*" == *"list-tags"* ]]; then
    if [[ "$*" == *"test-repo"* ]]; then
      # Return tags for incrementer testing
      cat <<EOF
{
  "Tags": ["release-1", "release-2", "release-5", "other-tag"]
}
EOF
    else
      # Return default tags
      cat <<EOF
{
  "Tags": ["latest", "v1.0.0", "v1.1.0"]
}
EOF
    fi
    return 0
  fi

  echo "Error: Unexpected skopeo call: $*"
  exit 1
}

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
    elif [[ "$3" == "templating" ]]; then
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
              "containerImage": "quay.io/valid-repo:templating-test",
              "name": "test-image",
              "source": {
                "git": {
                  "revision": "abc123def456789012345678901234567890abcd"
                }
              }
            }
          ]
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
        "repositories": [{"url":"quay.io/default-repo2"}],
        "tags": [
          "skip-image",
          "testtag"
        ]
      }'
    fi

    if [[ "$3" == "templating" ]]; then
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
                "repository": "quay.io/test-repo",
                "tags": [
                  "{{ git_short_sha }}",
                  "v1.0-{{ timestamp }}",
                  "build-{{ labels.version }}",
                  "release-{{ incrementer }}"
                ]
              }
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
      return
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

function get-image-architectures() {
  # Mock architecture data for templating tests
  echo '[{"platform":{"os":"linux","architecture":"amd64"}}]'
}

function oras() {
  if [[ "$1" == "resolve" && "$2" == "--registry-config" ]]; then
    # Check for platform + .src validation (image is in last argument)
    if [[ "$*" =~ "--platform" && "${@: -1}" =~ ".src" ]]; then
      echo "Error: .src images should not use --platform" >&2
      exit 1
    fi
    # Image is the last argument
    image="${@: -1}"
    if [[ "$image" == *skip-image* ]]; then
      echo "sha256:111111"
    else
      # echo the shasum computed from the pull spec so the task knows if two images are the same
      echo -n "sha256:"
      echo "$image" | sha256sum | cut -d ' ' -f 1
    fi
    return
  else
    echo Mock oras called with: $*
    echo Error: Unexpected call
    exit 1
  fi
}
