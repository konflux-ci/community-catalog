# notify-slack-on-failure

Tekton task that sends an error message to Slack using postMessage API if managed pipelines fail. test change here

## Parameters

| Name          | Description                                                       | Optional | Default Value |
|---------------|-------------------------------------------------------------------|----------|---------------|
| secretName    | Name of secret which contains authentication token for app        | No       | -             |
| secretKeyName | Name of key within secret which contains webhook URL              | No       | -             |
| release       | Namespaced name of release - should be in format "namespace/name" | No       | -             |
