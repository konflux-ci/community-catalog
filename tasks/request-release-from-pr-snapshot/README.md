# request-release-from-pr-snapshot

Create a Release for a pull request Snapshot and wait for it to complete.

Intended to run as an IntegrationTestScenario so that pull request builds
can be published (for example to a development registry) by an existing
tenant ReleasePlan. The task itself holds no registry credentials; the
ReleasePlan's pipeline and service account do the publishing.

The IntegrationTestScenario must be annotated with
test.appstudio.openshift.io/snapshot-param-as-name: "true" so that the
integration service passes the Snapshot name, not its serialized spec, as SNAPSHOT.

Guards:
- The Snapshot must come from a pull request: it has the
  pac.test.appstudio.openshift.io/pull-request annotation and is not from a push
  event (the same check integration-service uses, so builds triggered by PR
  comments such as /retest also qualify)
- The git revision of the component that triggered the Snapshot must match the
  pac.test.appstudio.openshift.io/sha label set by Pipelines as Code, so a PR
  cannot publish images under another commit's SHA tag
- The ReleasePlan must belong to the same application as the Snapshot
- The ReleasePlan must be labeled release.appstudio.openshift.io/auto-release: "false"
  so that it cannot be a ReleasePlan used for regular releases

The newest Release already created for the same Snapshot UID and ReleasePlan
is reused unless it failed, so re-running the test does not create duplicate
Releases but does retry a failed one.
The task succeeds or fails based on the Release's Released condition.

The TaskRun service account needs get access to Snapshots and ReleasePlans
and create, get, and list access to Releases in the namespace

## Parameters

| Name            | Description                                                                   | Optional | Default value |
|-----------------|-------------------------------------------------------------------------------|----------|---------------|
| SNAPSHOT        | Name of the pull request Snapshot in the TaskRun namespace                    | No       | -             |
| RELEASE_PLAN    | Name of the ReleasePlan in the TaskRun namespace to release the Snapshot with | No       | -             |
| TIMEOUT_SECONDS | How long to wait for the Release to complete                                  | Yes      | 3600          |
