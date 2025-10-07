# update-manager-image-in-git

Updates the image line in the manager yaml files in the internal-services component directories.

## Parameters

| Name         | Description                                                                                   | Optional | Default value                                            |
|--------------|-----------------------------------------------------------------------------------------------|----------|----------------------------------------------------------|
| deployment   | The deployment to be updated. Options are [staging, production]                               | No       | -                                                        |
| repoUrl      | The repo to update, starting with github.com, without https:// (e.g. github.com/org/repo.git) | Yes      | github.com/redhat-appstudio/infra-common-deployments.git |
| githubSecret | The secret containing a `token` key with value set to the GitHub access token                 | No       | -                                                        |
| image        | The manager image to update to                                                                | No       | -                                                        |
