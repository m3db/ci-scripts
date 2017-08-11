#!/bin/bash

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <metalinter-config-file> <exclude-file>"
  exit 1
fi

config_file=$1
exclude_file=$2

if [[ ! -f $exclude_file ]]; then
  echo "exclude-file ($exclude_file) does not exist"
  exit 1
fi

! gometalinter --config $config_file --vendor ./... | egrep -v -f $exclude_file
