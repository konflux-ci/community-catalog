#!/usr/bin/env bash
set -eu

function cosign() {
  if [[ "$1" == "copy" && "$2" == "-f" && "$3" == *":"* && "$4" == *":"* ]]
  then
    return 0
  fi

  echo "Error: Unexpected cosign call: $*"
  exit 1
}

function skopeo() {
  if [[ "$1" == "copy" && "$2" == "--all" ]]
  then
    echo "Skopeo copy executed (no attestations)"
    return 0
  fi

  echo "Error: Unexpected skopeo call: $*"
  exit 1
}

function docker-credential-gcr() {
  if [[ "$1" == "get" ]]; then
    echo '{"ServerURL":"https://us-docker.pkg.dev","Username":"_dcgcr_token","Secret":"mock-token"}'
    return 0
  fi

  echo "Error: Unexpected docker-credential-gcr call: $*"
  exit 1
}

function kubectl() {
  if [[ "$*" == *"snapshot"* ]]; then
    if [[ "$3" == "empty" ]]; then
      COMPONENTS="[]"
    elif [[ "$3" == "multiple" ]]; then
      COMPONENTS='[
        {"containerImage": "quay.io/valid-repo:tag", "name": "test-image",
         "source": {"git": {"revision": "abc123def456"}}},
        {"containerImage": "quay.io/valid-repo:tag2", "name": "test-image2",
         "source": {"git": {"revision": "abc123def456"}}}
      ]'
    elif [[ "$3" == "skip-image" ]]; then
      COMPONENTS='[
        {"containerImage": "quay.io/valid-repo:skip-image", "name": "test-image"}
      ]'
    elif [[ "$3" == "templating" ]]; then
      COMPONENTS='[
        {"containerImage": "quay.io/valid-repo:templating-test", "name": "test-image",
         "source": {"git": {"revision": "abc123def456789012345678901234567890abcd"}}}
      ]'
    else
      COMPONENTS='[
        {"containerImage": "quay.io/valid-repo:tag", "name": "test-image",
         "source": {"git": {"revision": "abc123def456"}}}
      ]'
    fi

    SPEC="{\"application\":\"demo\",\"artifacts\":{},\"components\":$COMPONENTS}"

    if [[ "$*" == *"jsonpath={.spec}"* ]]; then
      echo "$SPEC"
    else
      echo "{\"spec\":$SPEC}"
    fi

  elif [[ "$*" == *"releaseplan"* ]]; then
    if [[ "$3" == "skip-image" ]]; then
      DEST_REPO="us-docker.pkg.dev/my-project/my-repo/test-image"
    elif [[ "$3" == "multiple" ]]; then
      MAPPING='{
        "components": [
          {"name": "test-image",
           "repositories": [{"url": "us-docker.pkg.dev/my-project/my-repo/test-image",
           "tags": ["testtag"]}]},
          {"name": "test-image2",
           "repositories": [{"url": "us-docker.pkg.dev/my-project/my-repo/test-image2",
           "tags": ["testtag", "testtag2"]}]}
        ]
      }'
      if [[ "$*" == *"jsonpath={.spec.data.mapping}"* ]]; then
        echo "$MAPPING"
      else
        echo "{\"spec\":{\"data\":{\"mapping\":$MAPPING}}}"
      fi
      return
    elif [[ "$3" == "templating" ]]; then
      MAPPING='{
        "components": [
          {"name": "test-image",
           "repositories": [{"url": "us-docker.pkg.dev/my-project/my-repo/test-image",
           "tags": ["{{ git_sha }}", "{{ git_short_sha }}", "latest"]}]}
        ]
      }'
      if [[ "$*" == *"jsonpath={.spec.data.mapping}"* ]]; then
        echo "$MAPPING"
      else
        echo "{\"spec\":{\"data\":{\"mapping\":$MAPPING}}}"
      fi
      return
    elif [[ "$3" == "componenttags" ]]; then
      MAPPING='{
        "components": [
          {"name": "test-image",
           "componentTags": ["comp-tag"],
           "repositories": [{"url": "us-docker.pkg.dev/my-project/my-repo/test-image",
           "tags": ["repo-tag"]}]}
        ]
      }'
      if [[ "$*" == *"jsonpath={.spec.data.mapping}"* ]]; then
        echo "$MAPPING"
      else
        echo "{\"spec\":{\"data\":{\"mapping\":$MAPPING}}}"
      fi
      return
    else
      DEST_REPO="us-docker.pkg.dev/my-project/my-repo/default-image"
    fi

    MAPPING="{\"components\":[{\"name\":\"test-image\",\"repositories\":[{\"url\":\"$DEST_REPO\",\"tags\":[\"testtag\"]}]}]}"

    if [[ "$*" == *"jsonpath={.spec.data.mapping}"* ]]; then
      echo "$MAPPING"
    else
      echo "{\"spec\":{\"data\":{\"mapping\":$MAPPING}}}"
    fi
  fi
}

function select-oci-auth() {
  echo '{"auths":{"quay.io":{"auth":"dGVzdDp0ZXN0"}}}'
}

function oras() {
  if [[ "$1" == "resolve" ]]; then
    image="${*: -1}"
    if [[ "$image" == *"skip-image"* ]]; then
      echo "sha256:111111"
    elif [[ "$image" == *"not found"* ]]; then
      echo "Error response from registry: not found" >&2
      return 1
    else
      echo -n "sha256:"
      echo "$image" | sha256sum | cut -d ' ' -f 1
    fi
    return
  fi

  echo "Error: Unexpected oras call: $*"
  exit 1
}
