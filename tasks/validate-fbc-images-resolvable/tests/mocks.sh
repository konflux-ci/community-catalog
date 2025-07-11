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
  
  # Parse arguments to find URL and output file
  while [[ $# -gt 0 ]]; do
    case $1 in
      -o)
        output="$2"
        shift 2
        ;;
      -L)
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
      # Return source repositories
      echo "registry.redhat.io/ubi8"
      echo "registry.redhat.io/ubi9"
    elif [[ "$*" == *".mirrors[0]"* ]]; then
      # Return mirror repositories
      echo "mirror.example.com/ubi8"
      echo "mirror.example.com/ubi9"
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
  fi
}

function skopeo() {
  echo "Mock skopeo called with: $*"
  
  if [[ "$*" == *"inspect"* ]]; then
    local image=""
    
    # Parse arguments to find image
    while [[ $# -gt 0 ]]; do
      case $1 in
        inspect)
          shift
          ;;
        --tls-verify=false)
          shift
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
    
    # Mock different image availability scenarios
    if [[ "$image" == *"unavailable"* ]]; then
      echo "Error: Image not found"
      return 1
    elif [[ "$image" == *"mirror.example.com"* ]]; then
      echo '{"Name": "'"$image"'", "Digest": "sha256:abc123"}'
      return 0
    elif [[ "$image" == *"no-mirror"* ]]; then
      echo "Error: Image not found"
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
  command mapfile "$@"
}

function uname() {
  if [[ "$*" == "-m" ]]; then
    echo "x86_64"
  else
    command uname "$@"
  fi
} 
