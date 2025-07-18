# Combine Docker Config JSON Secrets

This task combines multiple Docker config JSON secrets into one.

## Description

This task takes in a JSON array of secret names and namespaces, reads each secret from the cluster, decodes and validates it, then merges its contents with an existing `auths` object in a single output file.


## Parameters

| Name             | Description                                                 | Optional | Default value |
| :--------------- | :---------------------------------------------------------- | :------- | :------------ |
| `auth-secrets`   | JSON array of secret name/namespace pairs for registry authentication. Must be provided as a valid JSON string. | Yes      | `"[]"`        |

## Results
| Name             | Description                                                 |
| :--------------- | :---------------------------------------------------------- |
| `auth-json`       | The combined JSON string content of the provided secrets.         | 

## Dependencies

The task runs on a `registry.access.redhat.com/ubi9/ubi:latest` base image and installs the following tools:

*   **`jq`**: Used to parse the `snapshot` JSON and merge authentication data.

*   **`kubectl`**: Used to read authentication secrets from the Kubernetes cluster.

## Usage Example

This task is designed to be used as a step within a larger Tekton Pipeline. The pipeline is responsible for providing the required parameters, such as the FBC image and the content of the IDMS file.

Here is an example of how to call this task from a `Pipeline`, overriding the default retry settings:

```yaml
- name: combine-dockercfgjson-secrets
  taskRef:
    name: combine-dockercfgjson-secrets
  params:
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
