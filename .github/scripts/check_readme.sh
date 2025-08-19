#!/bin/bash

# This script will verify that the README.md of all task and 
# pipeline directories provided matches the output of hack/readme_generator.sh
# to ensure that README files are up to date.
#
# Task and pipeline directories are provided
# either via README_ITEMS env var, or as arguments
# when running the script.

CLI_README_ITEMS=()
FAILED_ITEMS=()
FAILED_PARAMS=()
PYTHON_ONLY_FLAG=""

show_help() {
  echo "Usage: $0 [item1] [item2] [...]"
  echo
  echo Flags:
  echo "  --help: Show this help message"
  echo
  echo "Items are task or pipeline directories. They can be supplied"
  echo "either as arguments or via the README_ITEMS environment variable."
  echo
  echo "Examples:"
  echo "  $0 tasks/push-snapshot-to-quay pipelines/push-snapshot-to-quay tasks/task-name"
  echo
  echo "  or"
  echo
  echo '  export README_ITEMS="tasks/push-snapshot-to-quay pipelines/push-snapshot-to-quay tasks/task-name"'
  echo "  $0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      show_help
      ;;
    --*)
      show_help
      ;;
    *)
      CLI_README_ITEMS+=("$1")
      shift
      ;;
  esac
done

if [[ "${#CLI_README_ITEMS[@]}" -gt 0 ]]; then
  README_ITEMS=("${CLI_README_ITEMS[@]}")
else
  read -r -a README_ITEMS <<< "${README_ITEMS[@]}"
fi

if [ "${#README_ITEMS[@]}" -eq 0 ]
then
  show_help
fi

# Check that all directories exist. If not, fail
for ITEM in "${README_ITEMS[@]}"
do
  if [[ -d "$ITEM" ]]; then
    true
  else
    echo "Error: Invalid file or directory: $ITEM"
    exit 1
  fi
done

# Checking which yq is being used - Python version requires -r flag
if [[ "$(yq --version)" != *mikefarah* ]]; then
  echo "Using Python version of yq"
  PYTHON_ONLY_FLAG="-r"
else
  echo "Using Go version of yq"
fi

for ITEM in "${README_ITEMS[@]}"
do
  echo "Task/Pipeline item: $ITEM"
  ITEM_NAME=$(basename "$ITEM")
  ITEM_DIR=$(cut -d '/' -f -2 <<< "$ITEM")
  echo "  Task/Pipeline name: $ITEM_NAME"

  ITEM_PATH=${ITEM_DIR}/${ITEM_NAME}.yaml
  if [ ! -f "$ITEM_PATH" ]; then
    echo "  Error: Task/Pipeline file does not exist: $ITEM_PATH"
    exit 1
  fi

  if [[ $(yq $PYTHON_ONLY_FLAG ".spec | has(\"description\")" "$ITEM_PATH") == "false" ]]; then
    echo "  Error in $ITEM: Field '.spec.description' is missing in task"
    FAILED_ITEMS+=("$ITEM - no description")
  fi

  # Check description doesn't have '.' or ','
  PARAMS=$(yq $PYTHON_ONLY_FLAG .spec.params "$ITEM_PATH")
  for ((i=0; i < $(yq $PYTHON_ONLY_FLAG length <<< "$PARAMS"); i++)); do
    # Get rid of newlines and remove trailing whitespace
    DESCRIPTION="$(yq $PYTHON_ONLY_FLAG .[$i].description <<< "$PARAMS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    NAME="$(yq $PYTHON_ONLY_FLAG .[$i].name <<< "$PARAMS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

    if [[ $(yq $PYTHON_ONLY_FLAG ".[$i] | has(\"description\")" <<< "$PARAMS") == "false" ]]; then
      echo "  Error in $ITEM: Field '.param.[$i].description' ($NAME) is missing in task"
      FAILED_PARAMS+=("$ITEM_PATH: $NAME - missing description")
    elif [[ "${DESCRIPTION: -1}" =~ [.,] ]]; then
      echo "  Error in $NAME: Description should not end with a '${DESCRIPTION: -1}'"
      FAILED_PARAMS+=("$ITEM_PATH: $NAME - invalid description")
    fi
  done

  README_PATH=${ITEM_DIR}/README.md
  if [ ! -f "$README_PATH" ]
  then
    echo "  Error: README does not exist in $ITEM_DIR"
    FAILED_ITEMS+=("$ITEM - no README.md")
    continue
  fi

  if ! diff -u <(.github/scripts/readme_generator.sh --dry-run --no-debug "$ITEM_DIR") "$README_PATH"; then
    echo "  Error: README.md has not been updated. Please use hack/readme-generator.sh to" \
      "generate a new README.md to replace $ITEM/README.md"
    FAILED_ITEMS+=("$ITEM - outdated README.md")
  else
    echo "  README.md for $ITEM_DIR is up to date"
  fi

done

if [[ "${#FAILED_PARAMS[@]}" -eq 0 ]]; then
  echo
  echo "All task/pipeline parameter descriptions are valid."
else
  echo
  echo "Error: these task/pipeline parameter descriptions must be updated:"
  for PARAM in "${FAILED_PARAMS[@]}"; do
    echo "  $PARAM"
  done

  if [[ "${#FAILED_ITEMS[@]}" -eq 0 ]]; then
    exit 1
  fi
fi

if [[ "${#FAILED_ITEMS[@]}" -eq 0 ]]; then
  echo
  echo "All README.md files are up to date"
else
  echo
  echo "Error: these task/pipeline README.md files must be updated:"
  for ITEM in "${FAILED_ITEMS[@]}"; do
    echo "  $ITEM"
  done
  echo
  if [[ "${#FAILED_PARAMS[@]}" -eq 0 ]]; then
    echo "Add missing descriptions to tasks/pipelines (if there are any)," \
      "then try running the following command to fix this:"
  else
    echo "Fix any invalid or missing parameter descriptions and add missing descriptions" \
      "to tasks/pipelines (if there are any), then try running the" \
      "following command to fix this:"
  fi
  # Get unique items in array
  FAILED_ITEMS=("$(printf "%s\n" "${FAILED_ITEMS[@]% - *}" | sort -u )")
  echo "./.github/scripts/readme_generator.sh" "${FAILED_ITEMS[@]}"
  exit 1
fi
