# notify-slack-on-failure

Sends an error message to Slack using postMessage API if managed pipelines fail.

## Parameters

| Name          | Description                                                       | Optional | Default value |
|---------------|-------------------------------------------------------------------|----------|---------------|
| secretName    | Name of secret which contains authentication token for app        | No       | -             |
| secretKeyName | Name of key within secret which contains webhook URL              | No       | -             |
| release       | Namespaced name of release - should be in format "namespace/name" | No       | -             |
