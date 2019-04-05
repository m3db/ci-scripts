#!/bin/bash

set -exo pipefail

if [[ $# -ne 2 ]] && [[ $# -ne 3 ]]; then
  echo "Usage: $0 <metalinter-config-file> <exclude-file> [<lint-dir>]"
  exit 1
fi

config_file=$1
exclude_file=$2
lint_dir=${3:-.}

if [[ ! -f $exclude_file ]]; then
  echo "exclude-file ($exclude_file) does not exist"
  exit 1
fi

# NB(mschalle): gometalinter freaks out when running with go >= 1.10 and tries
# to lint the standard library. See
# https://github.com/alecthomas/gometalinter/issues/149 for more. Excluding
# GOROOT from linting fixes this. This is all a temporary fix until we're on
# https://github.com/golangci/golangci-lint, as gometalinter is deprecated.
GOROOT=$(eval "$(go env | grep GOROOT)" && echo "$GOROOT")

# Check the output of metalinting while not triggering any `set -e` failures.
LINT_OUT=$( (gometalinter --tests --config "$config_file" --exclude="$(basename "$GOROOT")" --vendor "$lint_dir/..." || true) | grep -Ev -f "$exclude_file" || true)
if [[ $LINT_OUT == "" ]]; then
	echo "Metalinted succesfully!"
	exit 0
fi

echo "$LINT_OUT"
if [[ $LINT_OUT == *"maligned"* ]]; then
	echo "If you received an error about struct size, try re-ordering the fields in descending order by size."
  echo "https://github.com/dominikh/go-tools/tree/master/cmd/structlayout"
  echo "http://golang-sizeof.tips"
fi
exit 1
