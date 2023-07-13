#!/usr/bin/env bash

# initialize local environment
. ./local-environment.sh

export REPORTS_DIR="reports"
export GLOBAL_ENV_FILE="${REPORTS_DIR}/environment.json"
export GLOBAL_ENV_EXP_FILE="${REPORTS_DIR}/global_environment.json"

usage() {
  echo "Usage: $0 <input-matrix.json>"
  exit 1
}

run_collection() {
  collection_json=$1

  if [[ -f $GLOBAL_ENV_EXP_FILE ]]; then
    cp $GLOBAL_ENV_EXP_FILE $GLOBAL_ENV_FILE
  fi

  TEST_NAME="$(echo "$collection_json" | jq -r '.name')"
  COLLECTION_PATH="$(echo "$collection_json" | jq -r '.collection')"
  DATA_PATH="$(echo "$collection_json" | jq -r '."iteration-data"')"
  _ENV_PATH="$(echo "$collection_json" | jq -r '.environment')"
  ENV_PATH="/tmp/$(basename "$_ENV_PATH")"

  echo "====================================================================================="
  echo "Running Test: $TEST_NAME"
  echo "Collection: $COLLECTION_PATH"
  echo "Data: $DATA_PATH"
  echo "Environment: $_ENV_PATH > $ENV_PATH"

  jq -n -f "$_ENV_PATH" >"$ENV_PATH"

  # Could've used postman/newman docker image, if not for the htmlextra reports.
  docker run \
    --volume "$PWD:/etc/newman" \
    --volume "/tmp:/tmp" \
    --tty dannydainton/htmlextra run "$COLLECTION_PATH" \
    --environment "$ENV_PATH" \
    --iteration-data "$DATA_PATH" \
    --globals "$GLOBAL_ENV_FILE" \
    --export-globals "$GLOBAL_ENV_EXP_FILE" \
    --bail --reporters cli,htmlextra,junit,json \
    --reporter-htmlextra-export "reports/${TEST_NAME}.html" \
    --reporter-htmlextra-title "$TEST_NAME Dashboard" \
    --reporter-htmlextra-browserTitle "$TEST_NAME Automation" \
    --reporter-htmlextra-titleSize "6" \
    --reporter-junit-export "reports/$TEST_NAME.xml" \
    --reporter-json-export "reports/$TEST_NAME.json"
  echo "====================================================================================="
}

create_reports_dir() {
  if [[ -d "$REPORTS_DIR" ]]; then
    rm -rf "$REPORTS_DIR"
  fi
  mkdir "$REPORTS_DIR"
  echo "{}" >"$GLOBAL_ENV_FILE"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
  fi
  create_reports_dir
  jq -c '.runs[]' "$1" | while read run; do run_collection "$run"; done
}

main $@
