# update-internal-services-resources pipeline

Tekton pipeline to copy the internal-services resource files and update the manager yamls
to the latest image in the github.com/redhat-appstudio/infra-common-deployments repository.

## Parameters

| Name         | Description                                                                                            | Optional | Default value |
|--------------|--------------------------------------------------------------------------------------------------------|----------|---------------|
| release      | The namespaced name (namespace/name) of the Release custom resource initiating this pipeline execution | No       | -             |
| repoUrl      | The repository where the internal-services manager files to update are                                 | No       | -             |
| githubSecret | The secret containing a TOKEN key to authenticate with GitHub to the repoUrl                           | No       | -             |
