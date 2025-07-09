# validate-fbc-images-resolvable pipeline

Tekton pipeline to validate a File-Based Catalog (FBC) by checking the availability of all its related images. It fetches an `ImageDigestMirrorSet` file from the component's source Git repository to resolve mirrors for unavailable images.

## Overview

The primary goal of this integration test is to ensure the integrity of an FBC image. It does this by:

1. Rendering the FBC using `opm` to extract a list of all related images.

2. Iterating through each related image and using `skopeo` to verify that it is available at its specified URL.

3. If an image is not available at its primary URL, the script checks for a mirror configuration in an `ImageDigestMirrorSet` (IDMS) file.

4. The pipeline passes if all images are either directly available or have a corresponding mirror configuration. It fails if any image is unavailable and has no mirror.

## Parameters

| Name | Description | Optional | Default value | 
 | ----- | ----- | ----- | ----- | 
| `SNAPSHOT` | A JSON string of an ApplicationSnapshot spec, provided by Konflux. It contains component details like the container image and source Git repository. | No | \- | 
| `PATH_TO_MIRROR_SET` | The path within the source Git repository to the `ImageDigestMirrorSet` configuration file. | Yes | `.tekton/images-mirror-set.yaml` | 
| `REPO_TOKEN` | The name of a Kubernetes Secret containing the access token needed to clone a private Git repository. | Yes | `""` | 
| `REPO_KEY` | The key within the `REPO_TOKEN` secret that holds the access token value. | Yes | `""` | 

## How It Works

This repository contains two main components:

1. **`validate-fbc-images-resolvable` (Task)**: A custom Tekton `Task` that contains the core validation logic. It installs dependencies and runs the validation script against a given FBC image and IDMS content.

2. **`validate-fbc-images-resolvable` (Pipeline)**: A Tekton `Pipeline` that orchestrates the entire validation process by chaining together several tasks:

   * **`parse-metadata`**: Extracts the FBC image URL and source Git repository details from the `SNAPSHOT` parameter.

   * **`fetch-idms-file`**: Downloads the `ImageDigestMirrorSet` file from the source repository. It can use the `REPO_TOKEN` and `REPO_KEY` parameters to authenticate with private repositories.

   * **`run-fbc-validation`**: Executes the `validate-fbc-images-resolvable` custom `Task`, passing the FBC image and the fetched IDMS content as parameters.

## Dependencies

The validation task runs on a `registry.access.redhat.com/ubi9/ubi:latest` base image and installs the following tools:

* **`opm v1.52.0`**: Used to render the FBC and list its contents.

* **`skopeo`**: Used to inspect remote container images and verify their availability.

* **`jq`**: Used to parse the `SNAPSHOT` JSON.

## Configuration and Usage

The pipeline can be invoked using an `IntegrationTestScenario` resource. You must update the `namespace`, `application`, and `resolverRef` sections to match your environment.

```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: IntegrationTestScenario
metadata:
  name: fbc-validation-scenario
  namespace: your-application-namespace # IMPORTANT: Change this
spec:
  application: your-application-name # IMPORTANT: Change this
  params:
    # The `SNAPSHOT` param is provided automatically by the context so it does not need to be set explicitly.
    # Setting it here will cause a conflict and the PipelineRun will fail to start.
    # - name: SNAPSHOT
    #   value: "$(context.release.snapshot)"
    - name: PATH_TO_MIRROR_SET
      value: ".tekton/images-mirror-set.yaml" # Optional: Override the default path to your IDMS file
    - name: REPO_TOKEN
      value: "my-private-repo-secret" # Optional: Name of the secret for private repo access
    - name: REPO_KEY
      value: "token" # Optional: Key in the secret that holds the token
  resolverRef:
    resolver: git
    params:
      - name: url
        value: "https://github.com/konflux-ci/community-catalog.git"
      - name: revision
        value: "development"
      - name: pathInRepo
        value: "pipelines/validate-fbc-images-resolvable/validate-fbc-images-resolvable.yaml"
```
