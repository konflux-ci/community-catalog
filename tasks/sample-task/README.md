# sample-task

Sample task that retrieves and prints Release and ReleasePlan CRs.

This task demonstrates how to work with Release and ReleasePlan custom resources
in the Konflux CI environment.

⚠️ Note: This is a sample task that should be kept simple to serve as a good example
of how to construct a tenant task, so any non-bugfix contributions should be moved
to a new or existing duplicate of this task.

## Parameters

| Name        | Description                                                            | Optional | Default value |
|-------------|------------------------------------------------------------------------|----------|---------------|
| release     | Namespaced name of release - should be in format "namespace/name"     | No       | -             |
| releasePlan | Namespaced name of release plan - should be in format "namespace/name"| No       | -             |