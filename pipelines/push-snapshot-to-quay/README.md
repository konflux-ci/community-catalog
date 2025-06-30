# push-snapshot-to-quay pipeline

Tekton task to push snapshot images to quay.io using `cosign copy`. The destination for
each image is taken from the '.spec.data.mapping' section of the release plan, in the form
'.spec.data.mapping.components.repository', and '.spec.data.mapping.components.tags'.

If `requireSuccessfulManagedRelease` is "true", the snapshot will only be pushed if it
contains a status indicating that a managed pipeline has successfully completed.

## Parameters

| Name                            | Description                                                                     | Optional | Default value                                       |
|---------------------------------|---------------------------------------------------------------------------------|----------|-----------------------------------------------------|
| releasePlan                     | Namespaced name of release plan - should be in format "namespace/name"          | No       | -                                                   |
| snapshot                        | Namespaced name of snapshot - should be in format "namespace/name"              | No       | -                                                   |
| taskGitUrl                      | The url to the git repo where the community-catalog tasks to be used are stored | Yes      | https://github.com/konflux-ci/community-catalog.git |
| taskGitRevision                 | The revision in the taskGitUrl repo to be used                                  | No       | -                                                   |
| release                         | Namespaced name of release - should be in format "namespace/name"               | No       | -                                                   |
| requireSuccessfulManagedRelease | Only push if the managed release status is successful                           | Yes      | false                                               |
