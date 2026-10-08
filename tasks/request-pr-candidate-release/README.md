# request-pr-candidate-release

Request a trusted candidate Release for a Gecko pull-request Snapshot.

The Snapshot must contain exactly one component, a pull_request event label,
and a full lowercase 40-character Git SHA matching its source revision.
Its application label must match spec.application. Only these fixed pairs
are supported:

- gecko-controllers/gecko-controllers: gecko-controllers-pr-candidate
- gecko-platform-api-server/gecko-platform-api-server: gecko-platform-api-server-pr-candidate

Releases are scoped to the TaskRun namespace and identified by Snapshot UID
and candidate ReleasePlan labels. A matching Release is reused only after
verifying both labels and spec fields. New Releases are read back and verified.
ManagedPipelineProcessed=False with reason Progressing remains pending;
other False reasons fail immediately. True with a valid condition reason
succeeds, including Succeeded or Skipped. Absent, unknown, or malformed
nonterminal conditions remain pending within the same fixed deadline.
Pending Releases are polled every 15 seconds for at most 3600 seconds.
Each API request is limited to 30 seconds or the remaining deadline, whichever
is smaller. A fixed one-hour Tekton step timeout bounds the entire execution.

The runner needs namespace-scoped get access to Snapshots and create, get,
and list access to Releases. It does not read Secrets or registry credentials.
The two candidate ReleasePlans must already exist in the namespace.

## Parameters

| Name     | Description                                                | Optional | Default value |
|----------|------------------------------------------------------------|----------|---------------|
| SNAPSHOT | Name of the pull-request Snapshot in the TaskRun namespace | No       | -             |
