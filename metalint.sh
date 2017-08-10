#!/bin/bash

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <metalinter-config-file> <exclude-file> [<optional-args>, ...]"
  exit 1
fi

config_file=$1
shift
exclude_file=$1
shift
additional_args=$*

if [[ ! -f $exclude_file ]]; then
  echo "exclude-file ($exclude_file) does not exist"
  exit 1
fi

! gometalinter --config $config_file --vendor "${additional_args}" ./... | egrep -v -f $exclude_file
