# sample-pipeline

Sample pipeline that demonstrates how to use the sample-task to retrieve and print Release and ReleasePlan CRs.

⚠️ Note: This is a sample pipeline that should be kept simple to serve as a good example
of how to construct a tenant task, so any non-bugfix contributions should be moved
to a new or existing duplicate of this pipeline.

## Parameters

| Name            | Description                                                               | Optional | Default value                                      |
|-----------------|---------------------------------------------------------------------------|----------|----------------------------------------------------|
| release         | Namespaced name of release - should be in format "namespace/name"        | No       | -                                                  |
| releasePlan     | Namespaced name of release plan - should be in format "namespace/name"   | No       | -                                                  |
| taskGitUrl      | The url to the git repo where the community-catalog tasks to be used are stored | No | https://github.com/konflux-ci/community-catalog.git |
| taskGitRevision | The revision in the taskGitUrl repo to be used                           | No       | -                                                  |