# Community Catalog

This repository contains a collection of tenant release tasks and pipelines, created and maintained by users.

If you have a tenant task/pipeline or final pipeline you think would be useful to others, feel free to contribute it here.

For instructions on how to use tenant tasks/pipelines and final pipelines, take a look at the [Konflux docs](https://konflux-ci.dev/docs/releasing/tenant-release-pipelines/).

Note: Tasks and pipelines in this repository are **not** maintained by the release team. If there is a problem in one of the tasks or pipelines, try using a
different branch, ask one of the task/pipeline owners, or submit a fix yourself (check [CONTRIBUTING.md](CONTRIBUTING.md) if you wish to contribute code).

## Resources

Here's a brief overview of what you can find in the different directories of this catalog:

`pipelines`: This directory contains tenant and final pipelines that can be used in a release plan.
`tasks`: The tasks directory holds Tekton Tasks that can be used in tenant or final pipelines.

## Linting of yaml files

Whenever a change is pushed to this repository and a pull request is created, a yaml lint task will run to ensure that the
resource definition doesn't contain invalid yaml data. Refer to the [.yamllint file](.yamllint) to see the exact applied
rules. For more information on yamllint, check the [official documentation](https://yamllint.readthedocs.io/en/stable).

## Promotions

The branches in this repo are automatically promoted every week on Wednesday at 14:15 UTC. Any commits in `staging` will be promoted to `production`,
and any commits in `development` will be promoted to `staging`.

All pull requests will be merged to `development`, promotions are the only way to push changes to the `staging` and `production` branches.
