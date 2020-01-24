#!/bin/bash

set -eo pipefail

# shellcheck disable=SC2001
DIR=$(<<<"$1" sed 's@[/|\.]@_@g')

OUT="${COVERTMP}/${DIR}"
if ! go test -v -race -timeout 5m -covermode=atomic -coverprofile="$OUT" "$1"; then
  echo "FAILED $1" > "$OUT"
  exit 1
fi
