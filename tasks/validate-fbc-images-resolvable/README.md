# validate-fbc-images-resolvable (Task)

A standalone Tekton `Task` that validates a File-Based Catalog (FBC) by checking the availability of all its related images. It uses an `ImageDigestMirrorSet` (IDMS) to check for mirrors if a primary image URL is unavailable. Supports multiple registry authentication sources from Kubernetes secrets.

## Overview

The primary goal of this task is to ensure the integrity of an FBC image. It does this by:

1. Rendering the FBC using `opm` to extract a list of all related images.

2. Iterating through each related image and using `skopeo` to verify that it is available at its specified URL.

3. If an image is not available at its primary URL, the script checks for a mirror configuration in the provided `idms-content`.

4. The task passes if all images are either directly available or have a corresponding mirror configuration. It fails if any image is unavailable and has no mirror.

5. Supports authentication to private registries by reading registry credentials from Kubernetes secrets.

### Authentication Support

The task can authenticate to private registries using credentials stored in Kubernetes secrets. You can specify multiple secrets from different namespaces, and the task will merge all authentication data into a single configuration file for registry access. The secrets should be of type `kubernetes.io/dockerconfigjson`.

Authentication errors are properly detected and distinguished from other types of failures. When authentication fails on a primary image URL, the task will continue checking for mirrors that might be publicly accessible or require different credentials.

### Retry Mechanism

The task includes a built-in retry mechanism to handle transient network issues or temporary image unavailability. The number of attempts and the interval between them are configurable via parameters.

A timeout for the entire task execution is not handled internally. For that, you should use the `timeout` field on the `TaskRun` or the pipeline task definition.

## Parameters

| Name             | Description                                                 | Optional | Default value |
| :--------------- | :---------------------------------------------------------- | :------- | :------------ |
| `fbc-image`      | The FBC image pull spec to be validated.                    | No       | -             |
| `idms-content`   | The string content of the `ImageDigestMirrorSet` YAML file. | No       | -             |
| `auth-secrets`   | JSON array of secret name/namespace pairs for registry authentication. Must be provided as a valid JSON string. | Yes      | `[]`          |
| `retries`        | The maximum number of validation attempts.                  | Yes      | `3`           |
| `retry-interval` | The time to wait between retries, in seconds.               | Yes      | `300`         |

## Dependencies

The task runs on a `registry.access.redhat.com/ubi9/ubi:latest` base image and installs the following tools:

* **`opm v1.52.0`**: Used to render the FBC and list its contents.

* **`skopeo`**: Used to inspect remote container images and verify their availability.

* **`jq`**: Used to parse the `snapshot` JSON and merge authentication data.

* **`kubectl`**: Used to read authentication secrets from the Kubernetes cluster.

* **`yq v4.45.4`**: Used to parse the IDMS YAML content.

## Usage Example

This task is designed to be used as a step within a larger Tekton Pipeline. The pipeline is responsible for providing the required parameters, such as the FBC image and the content of the IDMS file.

Here is an example of how to call this task from a `Pipeline`, overriding the default retry settings:

```yaml
- name: run-fbc-validation
  runAfter: [ "fetch-idms-file" ]
  taskRef:
    name: validate-fbc-images-resolvable
  params:
    - name: fbc-image
      value: $(tasks.parse-metadata.results.fbc-image)
    - name: idms-content
      value: $(tasks.fetch-idms-file.results.idms-content)
    - name: auth-secrets
      value: |
        [
          {
            "name": "registry-redhat-secret",
            "namespace": "my-namespace"
          },
          {
            "name": "quay-secret",
            "namespace": "my-namespace"
          },
          {
            "name": "stage-registry-secret",
            "namespace": "another-namespace"
          }
        ]
    - name: retries
      value: "3" # The default is 3
    - name: retry-interval
      value: "300" # The default is 300 seconds (5 minutes)
```

### Authentication Secrets Example

Registry authentication secrets should be of type `kubernetes.io/dockerconfigjson`. Here's an example of creating such a secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-redhat-secret
  namespace: my-namespace
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: |
    ewogICJhdXRocyI6IHsKICAgICJyZWdpc3RyeS5yZWRoYXQuaW8iOiB7CiAgICAgICJhdXRoIjogImJhc2U2NGVuY29kZWRjcmVkZW50aWFscyIKICAgIH0KICB9Cn0K
```

## RBAC Requirements

The task requires RBAC permissions to read secrets from the specified namespaces. The service account running this task needs the following permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: validate-fbc-secret-reader
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: validate-fbc-secret-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: validate-fbc-secret-reader
subjects:
- kind: ServiceAccount
  name: your-service-account
  namespace: your-namespace
```

Alternatively, you can use namespace-specific roles if the secrets are in the same namespace as the task:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: validate-fbc-secret-reader
  namespace: your-namespace
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: validate-fbc-secret-reader-binding
  namespace: your-namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: validate-fbc-secret-reader
subjects:
- kind: ServiceAccount
  name: your-service-account
  namespace: your-namespace
```
