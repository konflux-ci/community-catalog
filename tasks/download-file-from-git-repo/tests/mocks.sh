#!/usr/bin/env bash
set -eux

# mocks to be injected into task step scripts

function curl() {
  echo Mock curl called with: $* >&2
  echo $* >> /tmp/mock_curl.txt 2>&1
  
  local output_file=""
  local url=""
  local auth_header=""
  local http_code_flag=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -o)
        output_file="$2"
        shift 2
        ;;
      -w)
        if [[ "$2" == "%{http_code}" ]]; then
          http_code_flag=true
        fi
        shift 2
        ;;
      -H)
        auth_header="$2"
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
  
  # Determine response based on URL patterns
  if [[ "$url" == *"404-test"* ]]; then
    echo "404" # HTTP status code
    echo "File not found" > "$output_file"
    return 0
  elif [[ "$url" == *"empty-test"* ]]; then
    echo "200" # HTTP status code
    echo "" > "$output_file"  # Empty file
    return 0
  elif [[ "$url" == *"private-repo"* ]]; then
    if [[ -z "$auth_header" ]]; then
      echo "401" # HTTP status code
      echo "Unauthorized" > "$output_file"
      return 0
    elif [[ "$auth_header" == *"invalid-token"* ]]; then
      echo "403" # HTTP status code
      echo "Forbidden" > "$output_file"
      return 0
    elif [[ "$auth_header" == *"token-for-private-repo"* ]]; then
      echo "200" # HTTP status code
      if [[ -n "$output_file" ]]; then
        echo "private-github-file-content" > "$output_file"
      fi
      return 0
    else
      echo "200" # HTTP status code
      if [[ -n "$output_file" ]]; then
        echo "private-file-content" > "$output_file"
      fi
      return 0
    fi
  elif [[ "$url" == *"gitlab.com"* ]]; then
    # Handle GitLab URLs
    if [[ -n "$auth_header" ]]; then
      # Private GitLab repo with token
      if [[ "$auth_header" == *"PRIVATE-TOKEN: gitlab-token"* ]]; then
        echo "200" # HTTP status code
        echo "private-gitlab-file-content" > "$output_file"
        return 0
      elif [[ "$auth_header" == *"PRIVATE-TOKEN"* ]]; then
        echo "401" # HTTP status code
        echo "Unauthorized" > "$output_file"
        return 0
      else
        echo "401" # HTTP status code
        echo "Unauthorized" > "$output_file"
        return 0
      fi
    else
      # Public GitLab repo
      echo "200" # HTTP status code
      echo "public-gitlab-file-content" > "$output_file"
      return 0
    fi
  elif [[ "$url" == *"github.com"* ]]; then
    # Handle GitHub URLs
    if [[ -n "$auth_header" ]]; then
      # Private GitHub repo with token
      if [[ "$auth_header" == *"Authorization: token token-for-private-repo"* ]]; then
        echo "200" # HTTP status code
        echo "private-github-file-content" > "$output_file"
        return 0
      elif [[ "$auth_header" == *"Authorization: token"* ]]; then
        echo "401" # HTTP status code
        echo "Unauthorized" > "$output_file"
        return 0
      else
        echo "401" # HTTP status code
        echo "Unauthorized" > "$output_file"
        return 0
      fi
    else
      # Public GitHub repo
      echo "200" # HTTP status code
      echo "public-github-file-content" > "$output_file"
      return 0
    fi
  elif [[ "$url" == *"unknown-provider"* ]]; then
    echo "200" # HTTP status code
    echo "unknown-provider-content" > "$output_file"
    return 0
  else
    # Default success case
    echo "200" # HTTP status code
    echo "file-content-from-public-repo" > "$output_file"
    return 0
  fi
}

function kubectl() {
  if [[ "$*" == *"get secret"* ]]; then
    if [[ "$*" == *"missing-secret"* ]]; then
      echo "Error from server (NotFound): secrets \"missing-secret\" not found"
      return 1
    elif [[ "$*" == *"invalid-secret"* ]]; then
      # Check if jsonpath is used - if so, return empty (key missing)
      if [[ "$*" == *"jsonpath"* ]]; then
        echo ""
      else
        echo '{"data": {}}'  # Secret exists but key is missing
      fi
      return 0
    elif [[ "$*" == *"private-token"* ]]; then
      # Check if jsonpath is used to extract just the token
      if [[ "$*" == *"jsonpath"* && "$*" == *"data.token"* ]]; then
        echo "dG9rZW4tZm9yLXByaXZhdGUtcmVwbw=="  # Just the base64 token value
      else
        echo '{"data": {"token": "dG9rZW4tZm9yLXByaXZhdGUtcmVwbw=="}}'  # Full JSON
      fi
      return 0
    elif [[ "$*" == *"gitlab-token"* ]]; then
      # Check if jsonpath is used to extract just the token
      if [[ "$*" == *"jsonpath"* && "$*" == *"data.token"* ]]; then
        echo "Z2l0bGFiLXRva2Vu"  # Just the base64 token value
      else
        echo '{"data": {"token": "Z2l0bGFiLXRva2Vu"}}'  # Full JSON
      fi
      return 0
    elif [[ "$*" == *"empty-token"* ]]; then
      # Check if jsonpath is used to extract just the token
      if [[ "$*" == *"jsonpath"* && "$*" == *"data.token"* ]]; then
        echo ""  # Empty token value
      else
        echo '{"data": {"token": ""}}'  # Full JSON
      fi
      return 0
    else
      # Default case
      if [[ "$*" == *"jsonpath"* && "$*" == *"data.token"* ]]; then
        echo "dG9rZW4tZm9yLXByaXZhdGUtcmVwbw=="  # Just the base64 token value
      else
        echo '{"data": {"token": "dG9rZW4tZm9yLXByaXZhdGUtcmVwbw=="}}'  # Full JSON
      fi
      return 0
    fi
  fi
  
  # Default kubectl behavior
  echo "Mock kubectl called with: $*"
}

function base64() {
  if [[ "$*" == *"-d"* ]]; then
    # Decode base64 - read from stdin when using -d flag
    local input
    if [[ -t 0 ]]; then
      # If stdin is a terminal, use the argument
      input="$2"
    else
      # Read from stdin (pipe input)
      read -r input
    fi
    
    case "$input" in
      "dG9rZW4tZm9yLXByaXZhdGUtcmVwbw==")
        echo "token-for-private-repo"
        ;;
      "Z2l0bGFiLXRva2Vu")
        echo "gitlab-token"
        ;;
      "")
        echo ""
        ;;
      *)
        echo "invalid-token"
        ;;
    esac
  else
    # Encode base64
    echo "$(echo -n "$1" | base64)"
  fi
}

function xargs() {
  # Simple xargs implementation for trimming whitespace
  read -r input
  echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

function mktemp() {
  # Create a temporary file
  local temp_file="/tmp/download_test_$(date +%s%N)"
  touch "$temp_file"
  echo "$temp_file"
}

function cat() {
  # Use real cat but ensure it works with our test files
  command cat "$@"
} 
