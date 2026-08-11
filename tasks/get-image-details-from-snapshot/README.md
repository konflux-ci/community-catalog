# get-image-details-from-snapshot Task

This task retrieves a component's full container image string from a `Snapshot` resource. It then splits the string into the base image URL and the image digest, outputting them as results for use in subsequent tasks.

## Parameters

| Name | Description | Optional | Default Value |
| --- | --- | --- | --- |
| `snapshot-name` | The name of the `Snapshot` resource to query. | No | - |
| `component-name` | The name of the component within the `Snapshot` to find the image for. | No | - |
| `namespace` | The namespace where the `Snapshot` resource exists. | No | - |

## Results

| Name | Description |
| --- | --- |
| `image-url` | The URL of the container image (e.g., `quay.io/my-org/my-app`). |
| `image-digest` | The digest of the container image (e.g., `sha256:abcdef...`). |
