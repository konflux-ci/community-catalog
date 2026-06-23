# sanitize-and-push-plr pipeline

Final release pipeline that sanitizes a build PipelineRun and pushes it as an OCI artifact to Quay.
Intended to run after a managed release pipeline has pushed the container image to its permanent location.

## Description

After a managed release pipeline completes, this pipeline:

1. Finds the source build PipelineRun via the Snapshot annotation
(`appstudio.openshift.io/snapshot-source-pipelinerun`). If the annotation is absent, falls back to a label selector filtered by the `test.appstudio.openshift.io/pipelinerun` finalizer.
2. Sanitizes the PipelineRun JSON by stripping volatile metadata (uid, resourceVersion, timestamps, managedFields), integration-service labels and annotations, and execution status fields that differ on every run.
3. Replaces the `IMAGE_URL` and `IMAGE_DIGEST` results in the sanitized PipelineRun with the permanently released image location so downstream consumers reference the correct registry.
4. Pushes the sanitized PipelineRun as an OCI artifact (`application/vnd.appstudio.pipelinerun+json`) to the target Quay repository with two tags:
   - `<componentName>-latest` — overwritten on every run
   - `<componentName>-YYYYMMDD-HHMMSS` — timestamped snapshot for rollback
5. On success, removes the `test.appstudio.openshift.io/pipelinerun` finalizer from the source PipelineRun so it can be garbage-collected by the cluster. On failure the finalizer is intentionally preserved for investigation.

## Parameters

| Name | Description | Optional | Default value |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|---------------|
| release | The namespaced name (namespace/name) of the Release custom resource | No | - |
| snapshot | The namespaced name (namespace/name) of the Snapshot | No | - |
| releasePlan | The namespaced name (namespace/name) of the ReleasePlan | No | - |
| componentName | The Konflux component name, used to find the source build PipelineRun and prefix OCI artifact tags | No | - |
| ociArtifactRepo | Quay repository to push the sanitized PipelineRun OCI artifact to | No | - |
| ociArtifactSecret | Name of the `kubernetes.io/dockerconfigjson` Secret in the tenant namespace with push credentials for the target Quay repository. Auth key must be `quay.io`. | No | - |
| releasedImageRepo | Repository where the managed pipeline released the container image (e.g. `quay.io/my-org/my-image`). Used to set `IMAGE_URL` in the sanitized PipelineRun. Defaults to `ociArtifactRepo` if empty. | Yes | "" |

## Prerequisites

- The build push pipeline must add the finalizer
  `test.appstudio.openshift.io/pipelinerun` to the build PipelineRun. This prevents
  the PipelineRun from being garbage-collected before this pipeline can process it.
- A `kubernetes.io/dockerconfigjson` Secret named by `ociArtifactSecret` must exist in
  the tenant namespace with push credentials to the target Quay repository. The secret
  must use `quay.io` as the auth key (not the full repository path).
- The `serviceAccountName` specified in the ReleasePlan `finalPipeline` spec must have
  `get`, `list`, and `patch` RBAC for `PipelineRun` and `Snapshot` resources in the
  tenant namespace.

## Recovery

If the pipeline fails, the finalizer is left on the source PipelineRun intentionally.
To recover, trigger a new push-to-main build and remove the old finalizer manually:

```bash
kubectl patch pipelinerun <name> -n <namespace> --type=json \
  -p '[{"op":"remove","path":"/metadata/finalizers"}]'
```
