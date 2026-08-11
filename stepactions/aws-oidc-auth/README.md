# aws-oidc-auth (StepAction)

Authenticates to AWS using OIDC workload identity federation. Designed to be embedded
as a step in custom Tasks. For a standalone Task, see `tasks/aws-oidc-auth`.

## Parameters

| Name                | Description                                              | Optional | Default value   |
|---------------------|----------------------------------------------------------|----------|-----------------|
| roleArn             | ARN of the IAM role to assume                            | No       | -               |
| region              | AWS region for STS endpoint                              | Yes      | us-east-1       |
| sessionDuration     | Duration in seconds for temporary credentials (900-43200)| Yes      | 900             |
| oidcTokenVolume     | Name of the projected serviceAccountToken volume         | Yes      | oidc-token      |
| awsCredentialsVolume| Name of the emptyDir volume for credentials              | Yes      | aws-credentials |

## Usage

The parent Task must declare two volumes. Subsequent steps mount the credentials volume
and set `AWS_SHARED_CREDENTIALS_FILE`.

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: my-task-needing-aws
spec:
  volumes:
    - name: oidc-token
      projected:
        sources:
          - serviceAccountToken:
              audience: sts.amazonaws.com
              expirationSeconds: 3600
              path: token
    - name: aws-credentials
      emptyDir:
        medium: Memory
        sizeLimit: 1Mi
  steps:
    - ref:
        name: aws-oidc-auth
      params:
        - name: roleArn
          value: arn:aws:iam::123456789012:role/my-role
    - name: use-aws
      image: amazon/aws-cli:latest
      volumeMounts:
        - name: aws-credentials
          mountPath: /var/run/secrets/aws
          readOnly: true
      env:
        - name: AWS_SHARED_CREDENTIALS_FILE
          value: /var/run/secrets/aws/credentials
      script: |
        aws s3 ls s3://my-bucket/
```

## Security

See `tasks/aws-oidc-auth/README.md` for full security details, prerequisites, and
IAM trust policy configuration.
