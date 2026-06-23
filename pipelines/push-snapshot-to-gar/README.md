# push-snapshot-to-gar

Pipeline to push snapshot images to Google Artifact Registry (GAR) using
Workload Identity Federation (WIF) for keyless authentication.

See the [task README](../../tasks/push-snapshot-to-gar/README.md) for
prerequisites and detailed documentation.

## Parameters

| Name | Description | Optional | Default value |
|------|-------------|----------|---------------|
| release | Namespaced name of release (namespace/name) | No | - |
| releasePlan | Namespaced name of release plan (namespace/name) | No | - |
| snapshot | Namespaced name of snapshot (namespace/name) | No | - |
| taskGitUrl | The url to the git repo where the community-catalog tasks to be used are stored | Yes | https://github.com/konflux-ci/community-catalog.git |
| taskGitRevision | The revision in the taskGitUrl repo to be used | No | - |
| wifConfigMapName | Name of the ConfigMap containing GCP WIF credential configuration JSON | Yes | gar-wif-config |
| wifAudience | Expected audience claim for the projected service account token, must match the WIF provider's allowed_audiences | No | - |
| taskImage | Image with docker-credential-gcr, cosign, skopeo, oras, jq, kubectl, and select-oci-auth | Yes | quay.io/redhat-services-prod/gcp-hcp-tenant/gcp-release-utils@sha256:cca965aaf2d67bad3f4949bffe2e920bebae1ad2edd6c95391b5ca96ee7e8242 |
| skipAttestations | If true, skip copying attestations and signatures | Yes | false |
