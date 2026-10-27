# request-release-from-pr-snapshot pipeline

Create a Release for a pull request Snapshot and wait for it to complete.

Intended to be used as an IntegrationTestScenario pipeline so that pull
request builds are published by a dedicated, non auto-release ReleasePlan.
The IntegrationTestScenario must be annotated with
test.appstudio.openshift.io/snapshot-param-as-name: "true" so SNAPSHOT is the
Snapshot name. See the task README for the guards applied and the RBAC required

## Parameters

| Name            | Description                                                                     | Optional | Default value                                       |
|-----------------|---------------------------------------------------------------------------------|----------|-----------------------------------------------------|
| SNAPSHOT        | Name of the pull request Snapshot, passed in by the integration service         | No       | -                                                   |
| RELEASE_PLAN    | Name of the ReleasePlan to release the Snapshot with                            | No       | -                                                   |
| TIMEOUT_SECONDS | How long to wait for the Release to complete                                    | Yes      | 3600                                                |
| taskGitUrl      | The url to the git repo where the community-catalog tasks to be used are stored | Yes      | https://github.com/konflux-ci/community-catalog.git |
| taskGitRevision | The revision in the taskGitUrl repo to be used                                  | Yes      | development                                         |
