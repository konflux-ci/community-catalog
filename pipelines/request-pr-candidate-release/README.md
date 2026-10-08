# request-pr-candidate-release pipeline

Request a trusted PR candidate Release from a Snapshot and wait for its result.

See the [Task README](../../tasks/request-pr-candidate-release/README.md) for
Snapshot requirements, candidate mapping, namespace permissions, and prerequisites.

For branch testing, set taskGitUrl and taskGitRevision to the same repository
and revision used by the outer Pipeline Git resolver. Pin both resolvers to
the same immutable catalog commit for final validation.

## Parameters

| Name            | Description                                                                     | Optional | Default value                                       |
|-----------------|---------------------------------------------------------------------------------|----------|-----------------------------------------------------|
| SNAPSHOT        | Name of the pull-request Snapshot in the TaskRun namespace                      | No       | -                                                   |
| taskGitUrl      | The url to the git repo where the community-catalog tasks to be used are stored | Yes      | https://github.com/konflux-ci/community-catalog.git |
| taskGitRevision | The revision in the taskGitUrl repo to be used                                  | Yes      | development                                         |
