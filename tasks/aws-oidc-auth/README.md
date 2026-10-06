# aws-oidc-auth

Authenticates to AWS using OIDC workload identity federation (STS `AssumeRoleWithWebIdentity`).
No static AWS credentials required.

Uses the pipeline ServiceAccount's projected token to obtain temporary AWS session credentials.
Credentials are stored in an in-memory volume and never exposed via Task results or logs.

## Parameters

| Name            | Description                                                            | Optional | Default value |
|-----------------|------------------------------------------------------------------------|----------|---------------|
| roleArn         | ARN of the IAM role to assume                                          | No       | -             |
| region          | AWS region for STS endpoint                                            | Yes      | us-east-1     |
| sessionDuration | Duration in seconds for temporary credentials (900-43200)              | Yes      | 900           |
| image           | Container image for the run step                                       | Yes      | ubi9-minimal  |
| script          | Script to execute with AWS credentials available                       | Yes      | echo message  |

## Prerequisites

1. **Cluster OIDC issuer must be publicly accessible.** Verify:
   ```bash
   ISSUER=$(curl -sk "$(oc whoami --show-server)/.well-known/openid-configuration" | jq -r '.issuer')
   curl -s "${ISSUER}/.well-known/openid-configuration"
   ```

2. **Register an AWS IAM OIDC identity provider** for the cluster's issuer:
   ```bash
   ISSUER_HOST=$(echo "${ISSUER}" | sed 's|https://||')
   THUMBPRINT=$(openssl s_client -connect "${ISSUER_HOST%%/*}:443" \
     -servername "${ISSUER_HOST%%/*}" </dev/null 2>/dev/null | \
     openssl x509 -fingerprint -sha1 -noout | \
     sed 's/://g' | cut -d= -f2 | tr '[:upper:]' '[:lower:]')

   aws iam create-open-id-connect-provider \
     --url "${ISSUER}" \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list "${THUMBPRINT}"
   ```

3. **Create an IAM role** with a trust policy allowing the pipeline ServiceAccount:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [{
       "Effect": "Allow",
       "Principal": {
         "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/ISSUER_HOST_AND_PATH"
       },
       "Action": "sts:AssumeRoleWithWebIdentity",
       "Condition": {
         "StringEquals": {
           "ISSUER_HOST_AND_PATH:aud": "sts.amazonaws.com"
         },
         "StringLike": {
           "ISSUER_HOST_AND_PATH:sub": "system:serviceaccount:NAMESPACE:build-pipeline-*"
         }
       }
     }]
   }
   ```

## Usage

```yaml
- name: aws-task
  taskRef:
    name: aws-oidc-auth
  params:
    - name: roleArn
      value: arn:aws:iam::123456789012:role/my-role
    - name: image
      value: amazon/aws-cli:latest
    - name: script
      value: |
        aws sts get-caller-identity
        aws s3 cp s3://my-bucket/config.yaml /tmp/config.yaml
```

## Security

- The `authenticate` step runs with `set +x` for its entirety — shell tracing cannot leak the OIDC token, STS response, or credentials.
- No Task `results` are defined — credentials cannot leak to PipelineRun status or Tekton Results.
- Credentials are stored in an in-memory `emptyDir` volume (`medium: Memory`) with `0600` permissions — never written to disk.
- The OIDC token volume is only mounted in the `authenticate` step — the `run` step cannot access the raw ServiceAccount token.
- The credentials volume is mounted read-only in the `run` step.
- The volume is destroyed when the pod terminates.
- Use short `sessionDuration` values and least-privilege IAM policies.

## Scoping access

IAM trust policy `sub` conditions map to Kubernetes ServiceAccount names:

| Scope | Condition |
|-------|-----------|
| All builds in namespace | `system:serviceaccount:NAMESPACE:build-pipeline-*` |
| Single component | `system:serviceaccount:NAMESPACE:build-pipeline-COMPONENT` |
| Integration tests | `system:serviceaccount:NAMESPACE:konflux-integration-runner` |
