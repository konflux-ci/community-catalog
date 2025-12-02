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
  if [[ "$url" == *"kubectl"* ]]; then
    # Create a mock kubectl binary with the logic directly embedded
    cat > "$output" << 'EOF'
#!/bin/bash
echo "Mock kubectl called with: $*"

# Parse kubectl get secret command
if [[ "$*" == *"get secret"* && "$*" == *"jsonpath"* ]]; then
  # Extract secret name and namespace
  secret_name=""
  namespace="default"
  args=("$@")
  
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
    exit 1
  elif [[ "$secret_name" == "empty-secret" ]]; then
    # Return empty data for empty-secret to test the warning case
    echo ""
    exit 0
  elif [[ "$secret_name" == "test-registry-secret"* ]]; then
    # Return different mock auth based on secret name
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
    exit 1
  fi
else
  # Default mock behavior for other kubectl commands
  echo "Mock kubectl executed successfully"
fi
EOF
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

function mv() {
  echo "Mock mv called with: $*"
  command mv "$@"
}

function jq() {
  echo "Mock jq called with: $*" >&2
  
  if [[ "$*" == "length" ]]; then
    # Mock length for AUTH_SECRETS JSON array
    # Read from stdin to determine test scenario
    local input
    input=$(cat)
    
    # Count the number of auth secrets based on test scenario
    if [[ "$input" == *"test-registry-secret-1"* && "$input" == *"test-registry-secret-2"* ]]; then
      echo "2"
    elif [[ "$input" == *"test-registry-secret"* ]]; then
      echo "1"
    else
      echo "0"
    fi
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
      echo "empty-secret"
    else
      echo "test-registry-secret"
    fi
  elif [[ "$*" == *"-s"* ]]; then
    # Mock merging auth files
    local input
    input=$(cat)
    
    # Return merged JSON based on input
    if [[ "$input" == *"test-registry-secret-1"* ]]; then
      echo '{"auths":{"registry.example.com":{"auth":"dGVzdHVzZXIxOnRlc3RwYXNzMQ=="},"quay.io":{"auth":"dGVzdHVzZXIyOnRlc3RwYXNzMg=="}}}'
    else
      echo '{"auths":{"registry.example.com":{"auth":"dGVzdHVzZXI6dGVzdHBhc3M="}}}'
    fi
  elif [[ "$*" == "." ]]; then
    # Mock JSON validation
    local input
    input=$(cat)
    
    # Only fail validation for the specific invalid-json test case
    if [[ "$input" == "invalid-json" ]]; then
      echo "parse error: Invalid numeric literal at line 2, column 0" >&2
      return 1
    fi
    
    # Return the input for valid JSON
    echo "$input"
  else
    echo "Mock jq result"
  fi
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

function base64() {
  if [[ "$*" == "-d" ]]; then
    # Mock base64 decode - read from stdin and return mock JSON
    read -r input
    echo '{"auths":{"registry.example.com":{"auth":"dGVzdHVzZXI6dGVzdHBhc3M="}}}'
  else
    command base64 "$@"
  fi
} 