# download-file-from-git-repo (Task)

A reusable Tekton `Task` that fetches a single file from a Git repository using its raw HTTP endpoint. It supports both public and private repositories.

## Overview

This task is designed to download the content of a specific file from a given Git repository URL, revision, and path. It constructs the raw file URL and uses `curl` to fetch its content. For private repositories, it can authenticate using a token stored in a Kubernetes Secret.

## Parameters

| Name         | Description                                                                                             | Optional | Default value |
| :----------- | :------------------------------------------------------------------------------------------------------ | :------- | :------------ |
| `url`        | The base URL of the Git repository (e.g., `https://github.com/org/repo`).                               | No       | -             |
| `revision`   | The Git revision (branch, tag, or commit SHA) where the file is located.                                | No       | -             |
| `pathInRepo` | The full path to the file within the repository.                                                        | No       | -             |
| `REPO_TOKEN` | The name of the Kubernetes Secret that contains an access token for a private Git repository.           | Yes      | `""`          |
| `REPO_KEY`   | The key within the `REPO_TOKEN` secret that holds the access token value.                               | Yes      | `""`          |

## Results

| Name      | Description                         |
| :-------- | :---------------------------------- |
| `content` | The raw string content of the downloaded file. |

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
    - name: REPO_TOKEN
      value: "my-private-repo-secret" # Only needed for private repos
    - name: REPO_KEY
      value: "token" # Only needed for private repos
```
