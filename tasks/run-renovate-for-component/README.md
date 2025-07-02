# run-renovate-for-component Task

This Task runs Renovate directly to create a pull request that updates a component's image digest in a git repository.

## Parameters

| Name | Description | Optional | Default Value |
| --- | --- | --- | --- |
| `git-repository-url` | The full Git repository URL to update (e.g., `https://github.com/org/repo.git`). | No | - |
| `git-token-secret-name` | The name of the Kubernetes secret containing the Git hosting service token. | No | - |
| `git-token-secret-key` | The key within the `git-token-secret-name` that holds the token value. | Yes | `token` |
| `image-name` | The name of the container image to update (e.g., `quay.io/my-org/my-app`). | No | - |
| `new-digest` | The new image digest to update to (e.g., `sha256:abcdef...`). | No | - |
| `file-match` | A regex string to match files that should be scanned by Renovate. | Yes | `(^|/)Dockerfile$` |
| `match-strings` | A regex string with a capture group to find the exact image declaration line to be replaced. Example: `"FROM quay.io/my-org/my-app(@sha256:[a-f0-9]+|:[\\w.-]+)"` | No | - |

## Workspaces

| Name | Description |
| --- | --- |
| `shared-workspace` | A workspace for Renovate to clone the repository and store logs. This should be provided by the calling pipeline. |
