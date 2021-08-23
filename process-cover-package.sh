#!/bin/bash

set -eo pipefail

# shellcheck disable=SC2001
DIR=$(<<<"$1" sed 's@[/|\.]@_@g')

OUT="${COVERTMP}/${DIR}"

# If using any manual build tags, propagate them to `go test`.
TAGS=()
if [[ -n "$GO_BUILD_TAGS" ]]; then
  TAGS=("-tags" "${GO_BUILD_TAGS}")
fi

OUTPUT_FORMAT_ARG=""
if [[ $GO_TEST_OUTPUT_FORMAT == "json" ]]; then
    OUTPUT_FORMAT_ARG="-json"
fi

if ! go test "${TAGS[@]}" -v $OUTPUT_FORMAT_ARG -race -timeout "${TEST_TIMEOUT:-10m}" -covermode=atomic -coverprofile="$OUT" "$1"; then
  echo "FAILED $1" > "$OUT"
  exit 1
fi
