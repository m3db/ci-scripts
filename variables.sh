#!/bin/bash

# set PACKAGE in .travis.yml
export VENDOR_PATH=$PACKAGE/vendor
export LICENSE_BIN=$GOPATH/src/$PACKAGE/.ci/uber-licence/bin/licence
export GO15VENDOREXPERIMENT=1
export SRC=$(find ./ -maxdepth 10 -not -path '*/.git*' -not -path '*/.ci*' -not -path '*/_*' -not -path '*/vendor/*' -type d)

filter_cover_profile() {
  local input_profile_file=$1
  local output_file=$2
  local exclude_file=$3
  if [ -z $input_profile_file ] ;
    echo 'input_profile_file (i.e. $1) is not set'
    exit 1
  fi
  if [ -z $output_file ] ;
    echo 'output_file (i.e. $2) is not set'
    exit 1
  fi
  if [ ! -z $exclude_file ] && [ -f $exclude_file ] ;
    cat $input_profile_file | egrep -v -f $exclude_file > $output_file
  else
    cat $input_profile_file | grep -v "_mock.go" > $output_file
  fi
}

export -f filter_cover_profile
