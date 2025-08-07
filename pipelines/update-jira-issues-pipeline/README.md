# update-jira-issues-pipeline

Extracts JIRA issues from PR titles and updates them to a specified target state (default: ON_QA).

## Description

This pipeline automatically updates associated JIRA issues to a specified target state (default: "ON_QA"). It extracts JIRA issue references from the commit sha of a snapshot which contains pull request titles and adds comments with links to the snapshot where issues were fixed.

The pipeline uses the `update-jira-issues` task to perform the actual JIRA updates.

## Parameters

| Name                    | Description                                                                                    | Optional | Default value                                         |
|-------------------------|------------------------------------------------------------------------------------------------|----------|-------------------------------------------------------|

| snapshot                | The namespaced name (namespace/name) of the snapshot                                          | No       | -                                                     |
| taskGitUrl              | The url to the git repo where the community-catalog tasks to be used are stored              | Yes      | https://github.com/konflux-ci/community-catalog.git  |
| taskGitRevision         | The revision in the taskGitUrl repo to be used                                                | Yes      | main                                                  |
| jira_server             | The server of the Jira instance to update issues on                                           | Yes      | issues.redhat.com                                     |
| jira_project_regex      | The regex to match the Jira project to update issues on                                       | Yes      | "OCPBUGS-[0-9]+"                                      |
| jira_target_state       | The target Jira state to transition issues to                                               | Yes      | "ON_QA"                                               |
| jira_skip_states        | The Jira states that should be skipped                                                      | Yes      | "Verified,Release Pending,Closed"                     |

## Workspaces

| Name | Description                                              |
|------|----------------------------------------------------------|
| data | The workspace where the snapshot spec json file resides |

## Prerequisites

- A secret named `konflux-jira-secret` containing a `token` key with a valid Jira access token
- The snapshot must contain at least one component with a container image
- The container image must have `vcs-ref` and `url` labels pointing to a valid Git repository
- GitHub CLI (`gh`) must be available and configured for API access

## How it works

1. Receives a snapshot from a release pipeline
2. Passes the snapshot to the `update-jira-issues` task
3. The task extracts container images from all components in the snapshot
4. For each component:
   - Gets VCS reference and repository URL from the image labels
   - Uses GitHub API to fetch the pull request title associated with the commit
   - Extracts Jira issue ID from the PR title using the provided regex pattern
   - Checks the current status of the Jira issue
   - If the issue is in a skip state (e.g., "Verified", "Release Pending", "Closed"), skips processing
   - If the issue is not already in the target state:
     - Transitions the issue to the target state
     - Adds a comment with the staging build information
5. Continues processing remaining components

## Notes

- Currently only supports issues in issues.redhat.com due to authentication requirements
- Issues in other servers will be skipped without the pipeline failing
- The pipeline uses the default regex pattern `OCPBUGS-[0-9]+` to match Red Hat OpenShift bug tracker issues
- Issues in skip states (default: "Verified", "Release Pending", "Closed") will be skipped without processing