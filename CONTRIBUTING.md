# Contributing

Contributions of all kinds are welcome. In particular pull requests are appreciated.
You can contribute your own tasks and pipelines, or modify existing tasks and pipelines.

## Code of Conduct

Our [company values](https://www.redhat.com/en/about/brand/standards/culture)
guide us in our day-to-day interactions and decision-making. Our open source projects are
no exception and they will define the standards for how to engage with the project
through a [code of conduct](CODE_OF_CONDUCT.md).

Please, make sure you read both of them before contributing, so you can help us
to maintain a healthy community.

## Submitting changes

Before contributing code or documentation to this project, make sure you read the following sections.

## Sample Tasks and Pipelines

There are some sample tasks and pipelines you can use as an example when creating your own tenant tasks and pipelines:

- [notify-slack-on-failure](tasks/notify-slack-on-failure)

- [push-snapshot-to-quay](tasks/push-snapshot-to-quay)

## OWNERS files

This repository uses Prow review and approval plugins together with code ownership as encoded in OWNERS files to automatically select reviewers and merge pull requests.

OWNERS files are needed in every task/pipeline to enforce who the codeowners of tenant tasks and pipelines are. A check is run to ensure that each task and pipeline has an OWNERS file. 

Whenever a pull request is made to an existing task/pipeline, the OWNERS files in the task/pipeline will be checked and select two people at random from that file to review the pull request. For any changes outside of modifying an existing task/pipeline, two people from `release-service-maintainers` in the root OWNERS file will be selected for review (for example, adding a new task/pipeline).

For more information about the Prow process, check [the k8s docs](https://github.com/kubernetes/community/blob/master/contributors/guide/owners.md#the-code-review-process).

Note: only `/approve` is needed to merge a PR. `/lgtm` is not needed.

## Keeping Documentation Up to Date

Everything mentioned in this section is optional. If you want to use `.github/scripts/readme_generator.sh` to
automatically maintain your task/pipeline's README.md, you can follow the instructions in this section. Otherwise, you can
ignore the `Check README.md files` check on pull requests - it's not a required check.

Whenever a task or pipeline is changed, you can run the `.github/scripts/readme_generator.sh` script with the
changed task/pipeline directories as arguments to update the README.md description and parameter table.

You can run a check to see if the task/pipelines match the output of this script
 with the `.github/scripts/check_readme.sh` script.

This script also checks if descriptions are present in each task/pipeline (and their parameters) and that they don't end with
a trailing `.` or `,`

If you want to use `.github/scripts/readme_generator.sh` for your task/pipeline,
you should change the descriptions in the `yaml` file associated with the task/pipeline, and then run `.github/scripts/readme_generator.sh`
with the changed task/pipeline directories as arguments. This is because the task/pipeline `yaml` file is considered the source of truth for each 
task/pipeline README.md file. If you manually change the README.md file without updating the yaml, `check_readme.sh` will fail and `readme_generator.sh`
will overwrite your changes. You should never have to update the README.md file manually if you're using this script.

For more information, check the `.github/scripts/readme_generator.sh` and `.github/scripts/check_readme.sh` scripts.

## Commit message formatting and standards

The project follows the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification and enforces it using [gitlint](https://jorisroovers.com/gitlint/). The rules for this project are specified in the [.gitlint](.gitlint) config file. There is also a second rule file for the commit description that can be found in the [.github/gitlint directory](.github/gitlint).

The commit message should contain an overall explanation about the change and the motivation behind it. Please note that mentioning a Jira ticket ID or a GitHub issue, isn't a replacement for that.

A well formatted commit would look something like this:

```
feat(issue-id): what this commit does

Overall explanation of what this commit is achieving and the motivation behind it.

Signed-off-by: Your Name <your-name@your-email.com>
```

## Pull Request Title Prefixes

The title prefix should be one of (`chore`|`docs`|`feat`|`fix`|`refactor`|`revert`|`style`|`test`) followed by a colon (`:`) and lowercase title. Optionally, you can include a Jira key.

Examples:

- fix(KFLUXSPRT-794): pass content-gateway token
- feat: add rpms-signature-scan task

Title prefixes:

- **chore**: Changes that do not modify functionality (e.g., tool updates, or maintenance tasks).
- **docs**: Documentation updates or additions (e.g., README changes, inline comments).
- **feat**: Introduction of a new feature or functionality.
- **fix**: Bug fixes or corrections to existing functionality.
- **refactor**: Code changes that improve structure or readability without altering functionality.
- **revert**: Reverting a previous commit or pull request.
- **style**: Code formatting or stylistic changes that do not affect functionality (e.g., whitespace, linting).
- **test**: Adding or updating tests (e.g., unit tests, integration tests).

## Pull Requests

All changes must come from a pull request (PR) and cannot be directly committed. While anyone can engage in activity on a PR, pull requests are only approved by team members.

Before a pull request can be merged:

* The content of the PR has to be relevant to the PR itself
* The contribution must follow the style guidelines of this project
* Multiple commits should be used if the PR is complex and clarity can be improved, but they should still relate to a single topic
* For code contributions, tests have to be added/modified to ensure the code works
* There has to be at least one approval
* The feature branch must be rebased so it contains the latest changes from the target branch
* The CI has to pass successfully
* Every comment has to be addressed and resolved

## Tekton Task Testing

When a pull request is opened, Tekton Task tests are run for all the task directories
that are being modified.

The Github workflow is defined in
[.github/workflows/tekton_task_tests.yaml](.github/workflows/tekton_task_tests.yaml)

### Adding new Tekton Task tests

Tests are defined as Tekton Pipelines inside the `tests` subdirectory of the task
directory. Their filenames must match `test*.yaml` and the Pipeline name must be
the same as the filename (sans `.yaml`).

E.g. to add a test pipeline for `tasks/apply-mapping`, you can add a pipeline
such as `tasks/apply-mapping/tests/test-apply-mapping.yaml`.

To reference the task under test in a test pipeline, use just the name - the test
script will install the task CR locally. For example:

```yaml
- name: run-task
    taskRef:
      name: apply-mapping
```

Task tests are required for all new tasks. For task updates, if the task doesn't currently have tests, adding them is not strictly required, but is recommended.

#### Testing scenarios where the Task is expected to fail

When testing Tasks, most tests will test a positive outcome - that for some input, the task will pass
and provide the correct output. But sometimes it's desirable to test that a Task fails when
it's expected to fail, for example when invalid data is supplied as input for the Task.
But if the Task under test fails in the test Pipeline, the whole Pipeline will fail too. So we need
a way to tell the test script that the given test Pipeline is expected to fail.

You can do this by adding the annotation `test/assert-task-failure`
to the test pipeline object. This annotation will specify which task (`.spec.tasks[*].name`)
in the pipeline is expected to fail. For example:

```yaml
---
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: test-apply-mapping-fail-on-empty
  annotations:
    test/assert-task-failure: "run-task"
```

When this annotation is present, the test script will test that the pipeline fails
and also that it fails in the expected task.

#### Workspaces

Some tasks require one or multiple workspaces. This means that the test pipeline will also
have to declare a workspace and bind it to the workspace(s) required by the task under test.

Currently, the test script will pass a single workspace named `tests-workspace` mapping
to a 10Mi volume when starting the pipelinerun. This workspace can be used in the test pipeline.

#### Test Setup

Some task tests will require setup on the kind cluster before the test pipeline can run.
Certain things can be done in a setup task as part of the test pipeline, but others cannot.
For example, something like installing a CRD or modifying permissions for the service account that will
execute the test pipeline must be done before the test pipeline is executed.

In order to achieve this, a `pre-apply-task-hook.sh` script can be created in the `tests` directory for
a task. When the CI runs the testing, it will first check for this file. If it is found, it is executed
before the test pipeline. This script will run as the `kubeadmin` user. This approach is copied from the
tekton catalog repository. For more details and examples, look
[here](https://github.com/tektoncd/catalog/blob/main/CONTRIBUTING.md#end-to-end-testing).

Note: [mikefarah/yq](https://github.com/mikefarah/yq) is the expected version of `yq` for scripts in this repository.
A different `yq` command could lead to unexpected problems. You can check if you have the correct `yq` with `yq --version`.
You should get an output containing `(https://github.com/mikefarah/yq/)`.

#### Mocking commands executed in task scripts

Mocks are needed when we want to test tasks which call external services (e.g. `skopeo copy`,
`cosign download`, or even a python script from our release-utils image such as `create_container_image` that would
call Pyxis API). The way to do this is to create a file with mock shell functions (with the same names
as the commands you want to mock) and inject this file to the beginning of each `script` field in
the task step that needs mocking.

For reference implementation, check [push-snapshot-to-quay/tests/](tasks/push-snapshot-to-quay/tests/). Here's a breakdown of how it's done:

1. Create a `mocks.sh` file in the tests directory of your task, e.g.
    `tasks/create-pyxis-image/tests/mocks.sh`. This file will contain the mock function
    definitions. It also needs to contain a shebang at the top as it will get injected to the top
    of the original script. For example:

    ```sh
    #!/usr/bin/env sh
    set -eux

    function cosign() {
      echo Mock cosign called with: $*
      echo $* >> $(workspaces.data.path)/mock_cosign.txt

      if [[ "$*" != "download sbom --output-file myImageID"[12]".json imageurl"[12] ]]
      then
        echo Error: Unexpected call
        exit 1
      fi

      touch /workdir/sboms/${4}
    }
    ```

    In the example above, you can notice two things:
    - Each time the mock function is called, the full argument list is saved in a file in the
      workspace. This is optional and depends on your task's workspace name (If your task does not require a workspace, you don't need to add this).
      It allows us to check mock calls after task execution in our test pipeline.
    - In this case the function touches a file that would otherwise be created by the actual `cosign`
      call. This is specific to the task and will depend on your use case.
    - Note: In the example above, the function being mocked is `cosign`. If that function was actually something
      that had a hyphen in its name (e.g. `my-cool-function`), the tests would fail with
      `my-cool-function: not a valid identifier` messages. This is because when you use `#!/usr/bin/env sh`, Bash
      runs in POSIX mode in which case hyphens are not permitted in function names. The solution to this is to use
      `#!/bin/bash` or `#!/usr/bin/env bash` in place of `#!/usr/bin/env sh` at the top of the file. Keep in mind
      that the same shell declaration should be used in both the mock and the tekton task step script you are
      mocking to ensure the behavior during test is the same as during runtime.

1. In your `pre-apply-task-hook.sh` file (see the Test Setup section above for explanation), include
    `yq` commands to inject the `mocks.sh` file to the top of your task step scripts, e.g.:

    ```sh
    #!/usr/bin/env sh

    TASK_PATH=$1
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

    yq -i '.spec.steps[0].script = load_str("'$SCRIPT_DIR'/mocks.sh") + .spec.steps[0].script' $TASK_PATH
    yq -i '.spec.steps[1].script = load_str("'$SCRIPT_DIR'/mocks.sh") + .spec.steps[1].script' $TASK_PATH
    ```

    In this case we inject the file to both steps in the task under test. This will depend on
    the given task. You only need to inject mocks for the steps where something needs to be mocked.

1. (Optional) In your test pipeline, you can have a task after the main task under test that will
    check that the mock functions had the expected calls. This only applies if you saved your mock
    calls to a file. In our example, it will look something like this:

    ```sh
    if [ $(cat $(workspaces.data.path)/mock_cosign.txt | wc -l) != 2 ]; then
      echo Error: cosign was expected to be called 2 times. Actual calls:
      cat $(workspaces.data.path)/mock_cosign.txt
      exit 1
    fi
    ```

Note: The approach described above shows the recommended approach. But there may be variations
depending on your needs. For example, you could have several mocks files and inject different
files to different steps in your task.

### Running Tekton Task tests manually

Requirements:

* A k8s cluster running and kubectl default context pointing to it (e.g. [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation))
* Tekton installed in the cluster ([docs](https://tekton.dev/docs/pipelines/install/))

```
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

* tkn cli installed ([docs](https://tekton.dev/docs/cli/))

* jq installed

Once you have everything ready, you can run the test script and pass task version directories
as arguments, e.g.

```
./.github/scripts/test_tekton_tasks.sh tasks/check-if-related-test
```

This will install the task and run all test pipelines matching `tests/test*.yaml`.

Another option is to run one or more tests directly:

```
./.github/scripts/test_tekton_tasks.sh tasks/check-if-related-test/tests/test-check-if-related-test.yaml
```

This will still install the task and run `pre-apply-task-hook.sh` if present, but it will then
run only the specified test pipeline.

## Checkton check

This repository uses [checkton](https://github.com/chmeliik/checkton) to run [shellcheck](https://www.shellcheck.net) on the embedded shell in the Tekton resources.

This check shows itself as the `Linters / checkton (pull_request)` check on the pull request.

If it fails and you click details, the tool does a pretty good job of highlighting the failures and telling you how to fix them.

We strive to have all of our tekton resources abide by shellcheck, so this check is mandatory for pull requests submitted to this repo.
