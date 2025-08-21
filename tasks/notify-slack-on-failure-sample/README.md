# notify-slack-on-failure-sample

Sends an error message to Slack using postMessage API if managed pipelines fail.

⚠️ Note: This is a sample task that should be kept simple to serve as a good example
of how to construct a tenant task, so any non-bugfix contributions should be moved
to a new or existing duplicate of this task.

## Parameters

| Name          | Description                                                       | Optional | Default value |
|---------------|-------------------------------------------------------------------|----------|---------------|
| secretName    | Name of secret which contains authentication token for app        | No       | -             |
| secretKeyName | Name of key within secret which contains webhook URL              | No       | -             |
| release       | Namespaced name of release - should be in format "namespace/name" | No       | -             |
