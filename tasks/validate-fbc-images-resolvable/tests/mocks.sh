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
echo "yq version 4.50.1"' > "$output"
    chmod +x "$output"
  elif [[ "$url" == *"opm"* ]]; then
    # Create a mock opm binary
    echo '#!/bin/bash
echo "opm version 1.52.0"' > "$output"
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
    echo "yq version 4.50.1"
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
  elif [[ "$*" == *".auths | length"* ]]; then
    # Mock registry count in auth file
    echo "1"
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
    # Default to x86_64, but allow override via environment variable for testing
    echo "${MOCK_ARCH:-x86_64}"
  else
    command uname "$@"
  fi
}

function sha256sum() {
  echo "Mock sha256sum called with: $*" >&2
  
  # Check if we're validating a checksum (--check flag)
  if [[ "$*" == *"--check"* ]]; then
    # Read expected checksum and file from stdin
    local check_line
    read -r check_line
    
    # For testing, always return success (checksums match)
    # This allows tests to pass the new checksum validation
    local file=$(echo "$check_line" | awk '{print $2}')
    echo "$file: OK"
    return 0
  else
    # Calculate checksum (for echo -n "$file_content" | sha256sum cases)
    # Return a valid-looking checksum
    echo "abc123def456789012345678901234567890123456789012345678901234567890  -"
  fi
} 
