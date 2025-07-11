# check-if-related-test

This task checks if the current test suite is affected by changes in the pull request.
It determines if the pipeline under test is among the pipelines affected by the PR,
and sets the result accordingly.

## Parameters

| Name                | Description                                                                 | Optional | Default value |
|---------------------|-----------------------------------------------------------------------------|----------|---------------|
| pipeline-test-suite | The name of the test suite pipeline.                                        | No       | -             |
| pipeline-used       | The pipeline to use for the test suite. If empty, uses pipeline-test-suite. | No       | -             |
| component-image     | The image to use for running the check.                                     | No       | -             |
