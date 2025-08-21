# push-snapshot-to-quay-sample

Tekton task to push snapshot images to quay.io using `cosign copy`. The destination for
each image is taken from the '.spec.data.mapping' section of the release plan, in the form
'.spec.data.mapping.components.repository', and '.spec.data.mapping.components.tags'.

If `requireSuccessfulManagedRelease` is "true", the snapshot will only be pushed if it
contains a status indicating that a managed pipeline has successfully completed.

⚠️ Note: This is a sample task that should be kept simple to serve as a good example
of how to construct a tenant task, so any non-bugfix contributions should be moved
to a new or existing duplicate of this task.

## Parameters

| Name                            | Description                                                            | Optional | Default value |
|---------------------------------|------------------------------------------------------------------------|----------|---------------|
| release                         | Namespaced name of release - should be in format "namespace/name"      | No       | -             |
| releasePlan                     | Namespaced name of release plan - should be in format "namespace/name" | No       | -             |
| requireSuccessfulManagedRelease | Only push if the managed release status is successful                  | No       | -             |
| snapshot                        | Namespaced name of snapshot - should be in format "namespace/name"     | No       | -             |
| skipAttestations                | If true, skip copying attestations and signatures                      | Yes      | false         |
