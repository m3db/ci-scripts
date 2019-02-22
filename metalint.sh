#!/bin/bash

# metalint.sh is a thin wrapper around gometalinter which adds some useful
# debug output.

LINT_OUT=$(gometalinter $@)
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