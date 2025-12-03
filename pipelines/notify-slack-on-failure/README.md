# notify-slack-on-failure pipeline

Sends an error message to Slack using postMessage API if managed pipelines fail.
Optionally, it can also send a notification on success.

## Parameters

| Name            | Description                                                                     | Optional | Default value                                       |
|-----------------|---------------------------------------------------------------------------------|----------|-----------------------------------------------------|
| secretName      | Name of secret which contains authentication token for app                      | No       | -                                                   |
| secretKeyName   | Name of key within secret which contains webhook URL                            | No       | -                                                   |
| release         | Namespaced name of release - should be in format "namespace/name"               | No       | -                                                   |
| notifySuccess   | If set to "true", it will also send a notification on success.                  | Yes      | "false"                                             |
| taskGitUrl      | The url to the git repo where the community-catalog tasks to be used are stored | Yes      | https://github.com/konflux-ci/community-catalog.git |
| taskGitRevision | The revision in the taskGitUrl repo to be used                                  | No       | -                                                   |
