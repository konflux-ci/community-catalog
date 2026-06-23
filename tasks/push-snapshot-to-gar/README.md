# push-snapshot-to-gar

Push snapshot images to Google Artifact Registry (GAR) using `cosign copy`.

Authenticates to GAR via GCP Workload Identity Federation (WIF) — no static
service account keys required. Uses `docker-credential-gcr` as a Docker
credential helper to bridge WIF tokens into OCI registry credentials.

## Prerequisites

1. **GCP Workload Identity Pool and Provider** configured to trust the Konflux
   cluster's OIDC issuer
2. **GCP Service Account** with `roles/artifactregistry.writer` on the target
   GAR repository
3. **IAM binding** granting `roles/iam.workloadIdentityUser` to the Konflux
   pipeline service account's identity
4. **ConfigMap** in the tenant namespace containing the WIF credential
   configuration JSON (see [GCP external account credentials](https://cloud.google.com/iam/docs/workload-identity-federation-with-other-clouds#create_a_credential_configuration))
5. **Container image** with the following tools installed: `docker-credential-gcr`,
   `cosign`, `skopeo`, `oras`, `jq`, `kubectl`, and `select-oci-auth`. You can
   build your own or use the default `taskImage` parameter value

## Parameters

| Name | Description | Optional | Default value |
|------|-------------|----------|---------------|
| release | Namespaced name of release (namespace/name) | No | - |
| releasePlan | Namespaced name of release plan (namespace/name) | No | - |
| snapshot | Namespaced name of snapshot (namespace/name) | No | - |
| wifConfigMapName | Name of the ConfigMap containing GCP WIF credential configuration JSON | Yes | gar-wif-config |
| wifAudience | Expected audience claim for the projected service account token, must match the WIF provider's allowed_audiences | No | - |
| taskImage | Image with docker-credential-gcr, cosign, skopeo, oras, jq, kubectl, and select-oci-auth | Yes | quay.io/redhat-services-prod/gcp-hcp-tenant/gcp-release-utils@sha256:cca965aaf2d67bad3f4949bffe2e920bebae1ad2edd6c95391b5ca96ee7e8242 |
| skipAttestations | If true, skip copying attestations and signatures | Yes | false |

## Tag templating

The task supports the following tag template variables, which are replaced at
runtime using data from the snapshot:

| Variable | Description | Example output |
|----------|-------------|----------------|
| `{{ git_sha }}` | Full git commit SHA from `source.git.revision` | `a1b2c3d4e5f6...` |
| `{{ git_short_sha }}` | First 7 characters of the git commit SHA | `a1b2c3d` |

If a tag contains a template variable but `source.git.revision` is not set for
the component, the task will fail with a clear error.

> **Note**: The `{{ timestamp }}`, `{{ release_timestamp }}`, `{{ labels.* }}`,
> and `{{ incrementer }}` variables supported by `push-snapshot-to-quay` are not
> currently supported by this task.

## Example ReleasePlan data mapping

```yaml
spec:
  data:
    mapping:
      defaults:
        tags:
          - latest
      components:
        - name: my-component
          repositories:
            - url: us-docker.pkg.dev/my-project/my-repo/my-image
              tags:
                - "{{ git_sha }}"
                - "{{ git_short_sha }}"
```

## How it works

1. Reads the Snapshot and ReleasePlan to determine source images and destination
   repositories/tags
2. Authenticates to the source registry using `select-oci-auth`
3. Authenticates to GAR using `docker-credential-gcr` which:
   - Reads the projected SA token from `/var/run/secrets/tokens/oidc-token`
   - Exchanges it with GCP STS using the WIF credential config
   - Impersonates the GCP service account to get a GAR access token
4. Compares source and destination digests to skip unnecessary copies
5. Copies images using `cosign copy` (with attestations) or `skopeo copy`
   (without attestations)
