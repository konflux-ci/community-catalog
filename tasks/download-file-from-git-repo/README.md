# download-file-from-git-repo (Task)

A reusable Tekton `Task` that fetches a single file from a Git repository using its raw HTTP endpoint. It supports both public and private repositories.

## Overview

This task is designed to download the content of a specific file from a given Git repository URL, revision, and path. It constructs the raw file URL and uses `curl` to fetch its content. For private repositories, it can authenticate using a token stored in a Kubernetes Secret.

## Parameters

| Name             | Description                                                                                             | Optional | Default value |
| :--------------- | :------------------------------------------------------------------------------------------------------ | :------- | :------------ |
| `url`            | The base URL of the Git repository (e.g., `https://github.com/org/repo`).                               | No       | -             |
| `revision`       | The Git revision (branch, tag, or commit SHA) where the file is located.                                | No       | -             |
| `pathInRepo`     | The full path to the file within the repository.                                                        | No       | -             |
| `sha256_checksum` | The SHA256 checksum of the file to download. If provided, the task will verify the downloaded file matches this checksum. | Yes      | `""`          |
| `REPO_TOKEN`     | The name of the Kubernetes Secret that contains an access token for a private Git repository.           | Yes      | `""`          |
| `REPO_KEY`       | The key within the `REPO_TOKEN` secret that holds the access token value.                               | Yes      | `""`          |

## Results

| Name      | Description                         |
| :-------- | :---------------------------------- |
| `content` | The raw string content of the downloaded file. |

## Features

### Checksum Validation

When the `sha256_checksum` parameter is provided, the task will automatically verify the downloaded file's SHA256 checksum against the expected value. If the checksums don't match, the task will fail with an error message showing both the expected and calculated checksums.

This feature is useful for:
- Ensuring file integrity during download
- Detecting tampering or corruption
- Verifying exact file versions in security-sensitive contexts

To calculate the SHA256 checksum of a file:
```bash
sha256sum myfile.txt
```

## Usage Example

This task is designed to be used as a step within a larger Tekton Pipeline. The pipeline is responsible for providing the required parameters.

```yaml
- name: download-a-file
  taskRef:
    resolver: "git"
    params:
      - name: url
        value: https://github.com/konflux-ci/community-catalog.git
      - name: revision
        value: development
      - name: pathInRepo
        value: tasks/download-file-from-git-repo/download-file-from-git-repo.yaml
  params:
    - name: url
      value: "https://github.com/my-org/my-repo.git"
    - name: revision
      value: "my-branch"
    - name: pathInRepo
      value: "path/to/my/file.txt"
    - name: sha256_checksum
      value: "a1b2c3d4e5f6..." # Optional: Verify file integrity
    - name: REPO_TOKEN
      value: "my-private-repo-secret" # Only needed for private repos
    - name: REPO_KEY
      value: "token" # Only needed for private repos
```
