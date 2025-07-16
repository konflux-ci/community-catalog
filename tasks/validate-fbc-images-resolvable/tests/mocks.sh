#!/usr/bin/env bash
set -eux

# mocks to be injected into task step scripts

function dnf() {
  echo "Mock dnf called with: $*"
  if [[ "$*" == *"install"* ]]; then
    echo "Package installation successful"
  fi
}

function curl() {
  echo "Mock curl called with: $*"
  local url=""
  local output=""
  local use_remote_name=false
  
  # Parse arguments to find URL and output file
  while [[ $# -gt 0 ]]; do
    case $1 in
      -o)
        output="$2"
        shift 2
        ;;
      -O)
        use_remote_name=true
        shift
        ;;
      -LO)
        use_remote_name=true
        shift
        ;;
      -L)
        shift
        ;;
      -s)
        shift
        ;;
      http*)
        url="$1"
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
  
  # For -O flag, extract filename from URL
  if [[ "$use_remote_name" == true && -z "$output" ]]; then
    output=$(basename "$url")
  fi
  
  # Mock downloading based on URL patterns
  if [[ "$url" == *"yq"* ]]; then
    # Create a mock yq binary
    echo '#!/bin/bash
echo "yq version 4.45.4"' > "$output"
    chmod +x "$output"
  elif [[ "$url" == *"opm"* ]]; then
    # Create a mock opm binary
    echo '#!/bin/bash
echo "opm version 1.52.0"' > "$output"
    chmod +x "$output"
  elif [[ "$url" == *"kubectl"* ]]; then
    # Create a mock kubectl binary
    echo '#!/bin/bash
echo "kubectl version"' > "$output"
    chmod +x "$output"
  elif [[ "$url" == *"stable.txt"* ]]; then
    # Mock the kubectl version endpoint
    echo "v1.28.0"
  fi
}

function chmod() {
  echo "Mock chmod called with: $*"
  # Use real chmod for functionality
  command chmod "$@"
}

function opm() {
  echo "Mock opm called with: $*"
  
  if [[ "$*" == "version" ]]; then
    echo "opm version 1.52.0"
    return 0
  fi
  
  if [[ "$*" == *"render"* ]]; then
    local fbc_image=""
    
    # Parse arguments to find FBC image
    while [[ $# -gt 0 ]]; do
      case $1 in
        --skip-tls-verify)
          shift
          ;;
        render)
          shift
          ;;
        *)
          if [[ "$1" != -* ]]; then
            fbc_image="$1"
          fi
          shift
          ;;
      esac
    done
    
    # Mock different FBC scenarios
    if [[ "$fbc_image" == *"no-images"* ]]; then
      echo '{"schema": "olm.package"}'
    elif [[ "$fbc_image" == *"unavailable-images"* ]]; then
      cat <<EOF
{"schema": "olm.bundle", "relatedImages": [{"image": "quay.io/unavailable/image:v1.0.0@sha256:abc123"}]}
{"schema": "olm.bundle", "relatedImages": [{"image": "quay.io/unavailable/image2:v1.0.0@sha256:def456"}]}
EOF
    elif [[ "$fbc_image" == *"mirror-test"* ]]; then
      cat <<EOF
{"schema": "olm.bundle", "relatedImages": [{"image": "registry.redhat.io/ubi8/ubi:latest@sha256:abc123"}]}
{"schema": "olm.bundle", "relatedImages": [{"image": "registry.redhat.io/ubi9/ubi:latest@sha256:def456"}]}
EOF
    elif [[ "$fbc_image" == *"partial-mirror"* ]]; then
      cat <<EOF
{"schema": "olm.bundle", "relatedImages": [{"image": "registry.redhat.io/ubi8/ubi:latest@sha256:abc123"}]}
{"schema": "olm.bundle", "relatedImages": [{"image": "quay.io/no-mirror/image:v1.0.0@sha256:def456"}]}
EOF
    else
      # Default successful case
      cat <<EOF
{"schema": "olm.bundle", "relatedImages": [{"image": "quay.io/available/image:v1.0.0@sha256:abc123"}]}
{"schema": "olm.bundle", "relatedImages": [{"image": "quay.io/available/image2:v1.0.0@sha256:def456"}]}
EOF
    fi
  fi
}

function yq() {
  echo "Mock yq called with: $*"
  
  if [[ "$*" == "--version" ]]; then
    echo "yq version 4.45.4"
    return 0
  fi
  
  # Handle IDMS parsing
  if [[ "$*" == *".spec.imageDigestMirrors"* ]]; then
    if [[ "$*" == *".source"* ]]; then
      # Return source repositories (matching the test IDMS content)
      echo "registry.example.com/test"
    elif [[ "$*" == *".mirrors[0]"* ]]; then
      # Return mirror repositories (matching the test IDMS content)
      echo "mirror.example.com/test"
    fi
  fi
}

function jq() {
  echo "Mock jq called with: $*" >&2
  
  # This is used to extract related images from opm output
  if [[ "$*" == *"relatedImages"* ]]; then
    # Read input from stdin to determine test scenario
    local input
    input=$(cat)
    
    # Return based on input from opm
    if [[ "$input" == *"no-images"* ]] || [[ "$input" != *"relatedImages"* ]]; then
      # No related images found - return nothing
      return 0
    elif [[ "$input" == *"unavailable"* ]]; then
      echo "quay.io/unavailable/image:v1.0.0@sha256:abc123"
      echo "quay.io/unavailable/image2:v1.0.0@sha256:def456"
    elif [[ "$input" == *"partial-mirror"* ]]; then
      echo "registry.redhat.io/ubi8/ubi:latest@sha256:abc123"
      echo "quay.io/no-mirror/image:v1.0.0@sha256:def456"
    elif [[ "$input" == *"mirror-test"* ]] || [[ "$input" == *"registry.redhat.io"* ]]; then
      echo "registry.redhat.io/ubi8/ubi:latest@sha256:abc123"
      echo "registry.redhat.io/ubi9/ubi:latest@sha256:def456"
    else
      echo "quay.io/available/image:v1.0.0@sha256:abc123"
      echo "quay.io/available/image2:v1.0.0@sha256:def456"
    fi
  elif [[ "$*" == "length" ]]; then
    # Mock length for AUTH_SECRETS JSON array
    # Read from stdin to determine test scenario
    local input
    input=$(cat)
    
    # Count the number of auth secrets based on test scenario
    if [[ "$input" == *"test-registry-secret-1"* && "$input" == *"test-registry-secret-2"* && "$input" == *"test-registry-secret-3"* ]]; then
      echo "3"
    elif [[ "$input" == *"test-registry-secret"* ]]; then
      echo "1"
    else
      echo "0"
    fi
  elif [[ "$*" == *".auths | length"* ]]; then
    # Mock registry count in auth file
    echo "1"
  elif [[ "$*" == *"-r"* && "$*" == *".namespace"* ]]; then
    # Mock extracting namespace based on array index
    if [[ "$*" == *".[0].namespace"* ]]; then
      echo "default"
    elif [[ "$*" == *".[1].namespace"* ]]; then
      echo "test-namespace"
    elif [[ "$*" == *".[2].namespace"* ]]; then
      echo "default"
    else
      echo "default"
    fi
  elif [[ "$*" == *"-r"* && "$*" == *".name"* ]]; then
    # Mock extracting secret name based on array index
    if [[ "$*" == *".[0].name"* ]]; then
      echo "test-registry-secret-1"
    elif [[ "$*" == *".[1].name"* ]]; then
      echo "test-registry-secret-2"
    elif [[ "$*" == *".[2].name"* ]]; then
      echo "test-registry-secret-3"
    else
      echo "test-registry-secret"
    fi
  elif [[ "$*" == *"-s"* ]]; then
    # Mock merging auth files
    echo '{"auths":{"registry.example.com":{"auth":"dGVzdHVzZXI6dGVzdHBhc3M="}}}'
  elif [[ "$*" == "." ]]; then
    # Mock JSON validation
    return 0
  else
    echo "Mock jq result"
  fi
}

function skopeo() {
  echo "Mock skopeo called with: $*"
  
  if [[ "$*" == *"inspect"* ]]; then
    local image=""
    local authfile=""
    local creds=""
    
    # Parse arguments to find image and auth parameters
    while [[ $# -gt 0 ]]; do
      case $1 in
        inspect)
          shift
          ;;
        --tls-verify=false)
          shift
          ;;
        --authfile)
          authfile="$2"
          shift 2
          ;;
        --creds)
          creds="$2"
          shift 2
          ;;
        docker://*)
          image="${1#docker://}"
          shift
          ;;
        *)
          shift
          ;;
      esac
    done
    
    # Log authentication method used
    if [[ -n "$authfile" ]]; then
      echo "Mock skopeo using authfile: $authfile"
    elif [[ -n "$creds" ]]; then
      echo "Mock skopeo using credentials: $creds"
    fi
    
    # Mock different image availability scenarios
    if [[ "$image" == *"unavailable"* ]]; then
      echo "Error: failed to find image: unauthorized: authentication required" >&2
      return 1
    elif [[ "$image" == *"auth-required"* ]]; then
      # Simulate authentication failure if no auth provided
      if [[ -z "$authfile" && -z "$creds" ]]; then
        echo "Error: unauthorized: authentication required" >&2
        return 1
      else
        echo '{"Name": "'"$image"'", "Digest": "sha256:abc123"}'
        return 0
      fi
    elif [[ "$image" == *"mirror.example.com"* ]]; then
      echo '{"Name": "'"$image"'", "Digest": "sha256:abc123"}'
      return 0
    elif [[ "$image" == *"no-mirror"* ]]; then
      echo "Error: failed to find image: not found" >&2
      return 1
    else
      echo '{"Name": "'"$image"'", "Digest": "sha256:abc123"}'
      return 0
    fi
  fi
}

function sleep() {
  echo "Mock sleep called with: $*"
  # Don't actually sleep in tests
}

function timeout() {
  echo "Mock timeout called with: $*"
  # Skip the timeout duration and execute the command
  shift
  "$@"
}

function echo() {
  command echo "$@"
}

function cut() {
  command cut "$@"
}

function sort() {
  command sort "$@"
}

function uniq() {
  command uniq "$@"
}

function mapfile() {
  # mapfile is a bash builtin, not available on all systems
  # Simple implementation for testing
  local array_name="$2"
  eval "$array_name=()"
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      eval "$array_name+=('$line')"
    fi
  done
}

function uname() {
  if [[ "$*" == "-m" ]]; then
    echo "x86_64"
  else
    command uname "$@"
  fi
}

function kubectl() {
  echo "Mock kubectl called with: $*"
  
  # Parse kubectl get secret command
  if [[ "$*" == *"get secret"* && "$*" == *"jsonpath"* ]]; then
    # Extract secret name and namespace
    local secret_name=""
    local namespace="default"
    local args=("$@")
    
    for ((i=0; i<${#args[@]}; i++)); do
      if [[ "${args[i]}" == "secret" ]]; then
        secret_name="${args[i+1]}"
      elif [[ "${args[i]}" == "-n" ]]; then
        namespace="${args[i+1]}"
      fi
    done
    
    # Mock different secret scenarios
    if [[ "$secret_name" == "non-existent-secret" ]]; then
      echo "Error from server (NotFound): secrets \"non-existent-secret\" not found" >&2
      return 1
    elif [[ "$secret_name" == "test-registry-secret"* ]]; then
      # Return different mock auth based on secret name
      local mock_auth
      if [[ "$secret_name" == "test-registry-secret-1" ]]; then
        mock_auth='{"auths":{"registry.example.com":{"auth":"dGVzdHVzZXIxOnRlc3RwYXNzMQ=="}}}'
      elif [[ "$secret_name" == "test-registry-secret-2" ]]; then
        mock_auth='{"auths":{"quay.io":{"auth":"dGVzdHVzZXIyOnRlc3RwYXNzMg=="}}}'
      elif [[ "$secret_name" == "test-registry-secret-3" ]]; then
        mock_auth='{"auths":{"registry.redhat.io":{"auth":"dGVzdHVzZXIzOnRlc3RwYXNzMw=="}}}'
      else
        mock_auth='{"auths":{"registry.example.com":{"auth":"dGVzdHVzZXI6dGVzdHBhc3M="}}}'
      fi
      echo -n "$mock_auth" | base64 -w 0
    else
      echo "Error from server (NotFound): secrets \"$secret_name\" not found" >&2
      return 1
    fi
  else
    # Default mock behavior for other kubectl commands
    echo "Mock kubectl executed successfully"
  fi
}

function base64() {
  if [[ "$*" == "-d" ]]; then
    # Mock base64 decode - read from stdin and return mock JSON
    read -r input
    echo '{"auths":{"registry.example.com":{"auth":"dGVzdHVzZXI6dGVzdHBhc3M="}}}'
  else
    command base64 "$@"
  fi
} 
