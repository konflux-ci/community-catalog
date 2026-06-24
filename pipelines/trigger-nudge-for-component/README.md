# trigger-nudge-for-component Pipeline

This pipeline orchestrates a direct component nudge. It gets the new image details from the release snapshot and then runs the Renovate task to create a PR.

## Parameters

| Name | Description | Optional | Default Value |
| --- | --- | --- | --- |
| `snapshot-name` | The name of the `Snapshot` from the completed release. | No | - |
| `component-to-nudge` | The name of the component in the snapshot whose new image should be used for the update. | No | - |
| `git-repo-to-update` | The full Git URL of the repository that should receive the update pull request. | No | - |
| `git-token-secret-name` | The name of the Kubernetes secret (in the release namespace) containing the Git hosting service token. | No | - |
| `file-to-match` | A regex string for Renovate to find the file(s) to update (e.g., `Dockerfile`). | No | - |
| `image-line-match-string` | A regex string for Renovate to find the exact image declaration line to replace. | No | - |
| `namespace` | The application's namespace where the `Snapshot` resource exists. | No | - |

## Workspaces

| Name | Description |
| --- | --- |
| `trigger-nudge-for-component` | A workspace required by the pipeline which is used by the `run-renovate-for-component` task for cloning the repository and storing logs. This should be provided by the calling Release Plan. |
