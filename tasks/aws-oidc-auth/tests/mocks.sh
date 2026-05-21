#!/usr/bin/env bash
set -eux

# mocks to be injected into task step scripts

function curl() {
  # Log call without printing sensitive arguments (WebIdentityToken)
  echo "Mock curl called" >&2

  if [[ "$*" == *"AssumeRoleWithWebIdentity"* ]]; then
    # Validate required parameters are present
    if [[ "$*" != *"RoleArn="* ]]; then
      echo "Error: Missing RoleArn parameter" >&2
      exit 1
    fi
    if [[ "$*" != *"WebIdentityToken="* ]]; then
      echo "Error: Missing WebIdentityToken parameter" >&2
      exit 1
    fi

    # Check for invalid role ARN test case
    if [[ "$*" == *"invalid-role"* ]]; then
      cat <<'XMLEOF'
<ErrorResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
  <Error>
    <Type>Sender</Type>
    <Code>AccessDenied</Code>
    <Message>Not authorized to perform sts:AssumeRoleWithWebIdentity</Message>
  </Error>
</ErrorResponse>
XMLEOF
      return 0
    fi

    # Return mock STS response
    cat <<'XMLEOF'
<AssumeRoleWithWebIdentityResponse xmlns="https://sts.amazonaws.com/doc/2011-06-15/">
  <AssumeRoleWithWebIdentityResult>
    <Credentials>
      <AccessKeyId>ASIAMOCKACCESSKEYID00</AccessKeyId>
      <SecretAccessKey>MockSecretAccessKey1234567890abcdefghijk</SecretAccessKey>
      <SessionToken>MockSessionToken1234567890abcdefghijklmnopqrstuvwxyz</SessionToken>
      <Expiration>2099-01-01T00:00:00Z</Expiration>
    </Credentials>
    <SubjectFromWebIdentityToken>system:serviceaccount:test-ns:test-sa</SubjectFromWebIdentityToken>
    <AssumedRoleUser>
      <AssumedRoleId>AROAMOCKROLEID:konflux-test</AssumedRoleId>
      <Arn>arn:aws:sts::123456789012:assumed-role/test-role/konflux-test</Arn>
    </AssumedRoleUser>
  </AssumeRoleWithWebIdentityResult>
</AssumeRoleWithWebIdentityResponse>
XMLEOF
    return 0
  fi

  # Default: pass through
  command curl "$@"
}
export -f curl
