# Download File from Git Repo Task Tests

This directory contains tests for the `download-file-from-git-repo` task.

## Test Files

### Provider-Specific Tests
- `test-download-file-public-github.yaml` - Test downloading from a public GitHub repository
- `test-download-file-private-github.yaml` - Test downloading from a private GitHub repository  
- `test-download-file-public-gitlab.yaml` - Test downloading from a public GitLab repository
- `test-download-file-private-gitlab.yaml` - Test downloading from a private GitLab repository

### Error Handling Tests
- `test-download-file-404.yaml` - Test handling of 404 errors
- `test-download-file-empty.yaml` - Test handling of empty files
- `test-download-file-missing-secret.yaml` - Test handling of missing secrets
- `test-download-file-invalid-key.yaml` - Test handling of invalid secret keys
- `test-download-file-unknown-provider.yaml` - Test handling of unknown git providers

## Mock Functions

The `mocks.sh` file contains mock implementations of:
- `curl` - Simulates HTTP requests with different response codes and authentication
- `kubectl` - Simulates Kubernetes secret operations
- `base64` - Simulates base64 encoding/decoding
- `xargs` - Simulates whitespace trimming
- `mktemp` - Creates temporary files for testing

## Test Scenarios

### Success Cases
- Public GitHub repository file download
- Private GitHub repository with valid token
- Public GitLab repository file download
- Private GitLab repository with valid token

### Failure Cases
- HTTP 404 (file not found)
- Empty file content
- Missing Kubernetes secret
- Invalid secret key
- Unknown git provider

## Mock Behavior

The mock functions simulate different scenarios based on URL patterns and authentication:

### GitHub URLs (`github.com`)
- **No auth header**: Returns public GitHub content
- **With `Authorization: token` header**: Returns private GitHub content
- **With invalid auth**: Returns 401 Unauthorized

### GitLab URLs (`gitlab.com`)
- **No auth header**: Returns public GitLab content  
- **With `PRIVATE-TOKEN` header**: Returns private GitLab content
- **With invalid auth**: Returns 401 Unauthorized

### Special Test URLs
- URLs containing `404-test`: Return 404 Not Found
- URLs containing `empty-test`: Return empty content
- URLs containing `private-repo`: Require authentication
- URLs containing `unknown-provider`: Test unknown provider handling

## Running Tests

To run these tests with a Tekton testing framework:

```bash
# Run all tests
tkn test run tasks/download-file-from-git-repo/tests/

# Run specific test
tkn test run tasks/download-file-from-git-repo/tests/test-download-file-public-github.yaml

# Run provider-specific tests
tkn test run tasks/download-file-from-git-repo/tests/test-download-file-*-github.yaml
tkn test run tasks/download-file-from-git-repo/tests/test-download-file-*-gitlab.yaml
```

## Test Setup

The `pre-apply-task-hook.sh` script:
1. Injects mock functions into the task
2. Creates test secrets for private repository scenarios:
   - `private-token` - For GitHub private repos
   - `gitlab-token` - For GitLab private repos
   - `invalid-secret` - For testing invalid secret keys
   - `empty-token` - For testing empty tokens
3. Cleans up any existing test files 
