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

GCFLAGS=""
if [ "$DISABLE_CHECKPTR" = "true" ]; then
    GCFLAGS="-gcflags=all=-d=checkptr=0"
fi

if ! go test "${TAGS[@]}" -v -race $GCFLAGS -timeout 5m -covermode=atomic -coverprofile="$OUT" "$1"; then
  echo "FAILED $1" > "$OUT"
  exit 1
fi
