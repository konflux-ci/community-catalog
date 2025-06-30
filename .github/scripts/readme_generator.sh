#!/usr/bin/env bash

# Automatically generates a README.md for tasks and pipelines.
# Without the '--dry-run' flag, this will automatically replace the current task/pipeline README.md
#
# This script takes the '.spec.description' and '.spec.params' fields 
# from the associated task/pipeline to create the description and table in the README.md of this task/pipeline.
#
# If you wish to update the README.md description and table, please update the '.spec.description' or '.spec.table'
# field in the Tekton task/pipeline and run this script, instead of changing it manually in the README.md.
#
# Usage: ./readme_generator.sh tasks/apply-mapping

show_help() {
  echo "Usage: $0 [--dry-run] [item1] [item2] [...]"
  echo
  echo Flags:
  echo "  --help: Show this help message"
  echo "  --dry-run: Print the updated README.md files without changing"
  echo "             the current README.md in each task and pipeline"
  echo "  --no-debug: Don't print debug messages (except errors)"
  echo
  echo "Items are task or pipeline directories. They can be supplied"
  echo "either as arguments or via the README_ITEMS environment variable."
  echo
  echo "Examples:"
  echo "  $0 tasks/push-snapshot-to-quay"
  echo "  $0 --dry-run tasks/push-snapshot-to-quay"
    echo "  $0 --dry-run --no-debug tasks/push-snapshot-to-quay"
  echo
  echo "  or"
  echo
  echo '  export README_ITEMS="tasks/push-snapshot-to-quay pipelines/push-snapshot-to-quay tasks/task-name"'
  echo "  $0"
  exit 1
}

DRY_RUN=false
NO_DEBUG=false
CLI_README_ITEMS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-debug)
      NO_DEBUG=true
      shift
      ;;
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
  if [[ ! -d "$ITEM" ]]; then
    echo "Error: Invalid file or directory: $ITEM"
    exit 1
  fi

  ITEM_NAME=$(basename "$ITEM")
  ITEM_DIR=$(cut -d '/' -f -2 <<< "$ITEM")

  ITEM_PATH=${ITEM_DIR}/${ITEM_NAME}.yaml
  if [ ! -f "$ITEM_PATH" ]
  then
    echo "Error: Task/Pipeline file does not exist: $ITEM_PATH"
    exit 1
  fi
done

# Creating after checking all directories exist to simplify cleanup
TEMP_README=$(mktemp)

# Add table
for ITEM in "${README_ITEMS[@]}"
do
  ITEM_DIR=$(cut -d '/' -f -2 <<< "$ITEM")
  BASE_DIR=$(cut -d '/' -f 1 <<< "$ITEM")
  ITEM_NAME=$(basename "$ITEM")
  ITEM_PATH=${ITEM_DIR}/${ITEM_NAME}.yaml

  # Don't print any debug messages when no debug is true
  $NO_DEBUG || echo "Task/Pipeline item: $ITEM"
  $NO_DEBUG || echo "  Task/Pipeline name: $ITEM_NAME"

  # Variables for description of README.md
  METADATA_NAME=$(yq .metadata.name "$ITEM_PATH")
  SPEC_DESCRIPTION=$(yq .spec.description "$ITEM_PATH")

  # Variables for table
  PARAMS=$(yq .spec.params "$ITEM_PATH")

  # Get the maximum length for each column of table
  LONGEST_NAME=0
  LONGEST_DESCRIPTION=0
  LONGEST_DEFAULT=13
  LONGEST_OPTIONAL=8

  for ((i=0; i < $(yq length <<< "$PARAMS"); i++)); do
    # Get rid of newlines and remove trailing whitespace
    NAME="$(yq .[$i].name <<< "$PARAMS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    DESCRIPTION="$(yq .[$i].description <<< "$PARAMS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    DEFAULT="$(yq .[$i].default <<< "$PARAMS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

    if [[ ${#NAME} -gt $LONGEST_NAME ]]; then
      LONGEST_NAME=${#NAME}
    fi
    
    if [[ ${#DESCRIPTION} -gt $LONGEST_DESCRIPTION ]]; then
      LONGEST_DESCRIPTION=${#DESCRIPTION}
    fi

    if [[ ${#DEFAULT} -gt $LONGEST_DEFAULT ]]; then
      LONGEST_DEFAULT=${#DEFAULT}
    fi
  done

  # create table and write contents to file
  {
    if [[ "$BASE_DIR" == "pipelines" && "$ITEM_NAME" != *-pipeline ]]; then
      echo "# $METADATA_NAME pipeline"
    elif [[ "$BASE_DIR" == "pipelines" && "$ITEM_NAME" == *-pipeline ]]; then
      echo "# ${METADATA_NAME%-pipeline} pipeline"
    else
      echo "# $METADATA_NAME"
    fi
    echo
    echo "$SPEC_DESCRIPTION"
    echo
    echo "## Parameters"
    echo

    # Print first row of table
    printf '| Name %*s' "$(($LONGEST_NAME-4))"
    printf '| Description %*s' "$(($LONGEST_DESCRIPTION-11))"
    printf '| Optional %*s' "$(($LONGEST_OPTIONAL-8))"
    printf '| Default value %*s|\n' "$(($LONGEST_DEFAULT-13))"

    # Print second row of table
    printf '|-%*s-' "$(($LONGEST_NAME))" | tr ' ' '-'
    printf '|-%*s-' "$(($LONGEST_DESCRIPTION))" | tr ' ' '-'
    printf '|-%*s-' "$(($LONGEST_OPTIONAL))" | tr ' ' '-'
    printf '|-%*s-|\n' "$(($LONGEST_DEFAULT))" | tr ' ' '-'

    # Print remaining rows of table
    for ((i=0; i < $(yq length <<< "$PARAMS"); i++)); do
      # Get rid of newlines and remove trailing whitespace
      NAME="$(yq .[$i].name <<< "$PARAMS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
      DESCRIPTION="$(yq .[$i].description <<< "$PARAMS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
      DEFAULT="$(yq .[$i].default <<< "$PARAMS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')"

      printf "| $NAME %*s" "$(($LONGEST_NAME-${#NAME}))"
      printf "| $DESCRIPTION %*s" "$(($LONGEST_DESCRIPTION-${#DESCRIPTION}))"

      # Check that default doesn't exist
      if [[ $(yq ".[$i] | has(\"default\")" <<< "$PARAMS") == "false" ]]; then
        printf "| No %*s" "$(($LONGEST_OPTIONAL-2))"
        printf "| - %*s|\n" "$(($LONGEST_DEFAULT-1))"
      else
        # Special case to show default empty strings as "" in table
        if [[ -z "$DEFAULT" ]]; then
          DEFAULT="\"\""
        fi
        printf "| Yes %*s" "$(($LONGEST_OPTIONAL-3))"
        printf "| $DEFAULT %*s|\n" "$(($LONGEST_DEFAULT-${#DEFAULT}))"
      fi
    done
  } > "$TEMP_README"

  if [[ $DRY_RUN == "true" ]]; then
    cat "$TEMP_README"
  else
    cat "$TEMP_README" > "${ITEM_DIR}/README.md"
  fi
  $NO_DEBUG || $DRY_RUN || echo "  README.md for $ITEM_DIR updated"
done

# Cleanup
if [ -v TEMP_README ]; then
  rm -f "$TEMP_README"
fi
