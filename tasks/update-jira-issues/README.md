# update-jira-issues

Updates Jira issues to a specified target state (default: ON_QA) when a staging build is released. Adds a comment to the issue with a link to the snapshot where it was fixed.

## Description

This task extracts Jira issue references from pull request titles in a release snapshot and updates those issues to a specified target state (default: "ON_QA"). It is designed to run after a staging build is released to automatically track issue progression.

**Note:** This task currently only supports issues in issues.redhat.com due to authentication requirements. Issues in other servers will be skipped without the task failing.

## Parameters

| Name               | Description                                                                                    | Optional | Default value                                         |
|-------------------|------------------------------------------------------------------------------------------------|----------|-------------------------------------------------------|
| snapshot          | The namespaced name (namespace/name) of the snapshot                                          | No       | -                                                     |
| jira_server       | The server of the Jira instance to update issues on                                           | Yes      | issues.redhat.com                                     |
| jira_project_regex| The regex to match the Jira project to update issues on                                       | Yes      | "OCPBUGS-[0-9]+"                                      |
| jira_target_state| The target Jira state to transition issues to                                               | Yes      | "ON_QA"                                               |
| jira_skip_states| The Jira states that should be skipped                                                      | Yes      | "Verified,Release Pending,Closed"                     |

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

1. Extracts container images from all components in the snapshot
2. For each component:
   - Gets VCS reference and repository URL from the image labels
   - Uses GitHub API to fetch the pull request title associated with the commit
   - Extracts Jira issue ID from the PR title using the provided regex pattern
   - Checks the current status of the Jira issue
   - If the issue is in a skip state (e.g., "Verified", "Release Pending", "Closed"), skips processing
   - If the issue is not already in the target state:
     - Transitions the issue to the target state
     - Adds a comment with the staging build information
   - If the issue is already in the target state, skips processing
3. Continues processing remaining components

## Behavior

- **Success**: Task completes successfully when all components are processed
- **Skip**: If no Jira issue is found in a PR title, that component is skipped and processing continues
- **Skip**: If an issue is in a skip state or already in the target state, that component is skipped and processing continues
- **Error**: If no container images can be extracted from the snapshot, the task exits with code 1
- **Error**: If a component has an empty image, the task exits with code 1
