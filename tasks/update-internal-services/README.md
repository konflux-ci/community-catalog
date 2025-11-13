# update-internal-services

Creates a PR to update the internal-services resources from the sha of the internal-services repo and
bump the image lines in the manager yaml files to the specified version.

## Parameters

| Name         | Description                                                                                   | Optional | Default value                                            |
|--------------|-----------------------------------------------------------------------------------------------|----------|----------------------------------------------------------|
| deployment   | The deployment to be updated. Options are [staging, production]                               | No       | -                                                        |
| repoUrl      | The repo to update, starting with github.com, without https:// (e.g. github.com/org/repo.git) | Yes      | github.com/redhat-appstudio/infra-common-deployments.git |
| githubSecret | The secret containing a `token` key with value set to the GitHub access token                 | No       | -                                                        |
| image        | The manager image to update to                                                                | No       | -                                                        |
