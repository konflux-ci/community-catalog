#!/bin/bash

# This script will check for an OWNERS file in all task and pipeline 
# directories provided either via DIRECTORIES env var, or as 
# arguments when running the script.
#
# Examples of usage:
# export DIRECTORIES="mydir/tasks/apply-mapping some/other/dir"
# ./check_owners.sh
#
# or
#
# ./check_owners.sh mydir/tasks/apply-mapping some/other/dir

if [ $# -gt 0 ]; then
  DIRECTORIES=$@
fi

if [ -z "${DIRECTORIES}" ]; then
  echo Error: No directories as argument.
  echo Usage:
  echo "$0 [item1] [item2] [...]"
  exit 1
fi

TEAM_NAME=release-service-maintainers

# check every item is a directory
for DIR in $DIRECTORIES; do
  if [[ -d "$DIR" ]]; then
    true
  else
    echo "Error: Not a directory: $DIR"
    exit 1
  fi

  OWNERS=${DIR}/OWNERS

  if [ ! -f $OWNERS ]; then
    echo Error: OWNERS file does not exist: $SHORT_DIR
    exit 1
  fi

  REGEX="(\s)$TEAM_NAME($|\s)"

  if [[ $(cat $OWNERS) =~ $REGEX ]]; then
    echo "Error: $TEAM_NAME cannot be" \
      "included as a code owner."
    exit 1 
  fi

  echo "$OWNERS exists and does not contain $TEAM_NAME"

done
