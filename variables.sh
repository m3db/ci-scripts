#!/bin/bash
# set PACKAGE in .travis.yml
export VENDOR_PATH=$PACKAGE/vendor
export LICENSE_BIN=$GOPATH/src/$PACKAGE/.ci/uber-licence/bin/licence
export GO15VENDOREXPERIMENT=1
export GOPATH
GOPATH=$(eval "$(go env | grep GOPATH)" && echo "$GOPATH")

FIND_ROOT="./"
if [ "$SRC_ROOT" != "" ]; then
  FIND_ROOT=$SRC_ROOT
fi

find_dirs() {
  find $FIND_ROOT -maxdepth 10 -not -path '*/.git*' -not -path '*/.ci*' -not -path '*/_*' -not -path '*/vendor/*' -type d
}

BASE_SRC=$(find_dirs)
if [ "$SRC_EXCLUDE" != "" ]; then
  BASE_SRC=$(find_dirs | grep -v $SRC_EXCLUDE)
fi
export SRC=$BASE_SRC

filter_cover_profile() {
  local input_profile_file=$1
  local output_file=$2
  local exclude_file=$3
  if [ -z $input_profile_file ] ; then
    echo 'input_profile_file (i.e. $1) is not set'
    exit 1
  fi
  if [ -z $output_file ] ; then
    echo 'output_file (i.e. $2) is not set'
    exit 1
  fi
  if [ ! -z $exclude_file ] && [ -f $exclude_file ] ; then
    cat $input_profile_file | egrep -v -f $exclude_file | grep -v 'mode:' >> $output_file
  else
    cat $input_profile_file | grep -v "_mock.go" | grep -v 'mode:' >> $output_file
  fi
}

export -f filter_cover_profile

# go1.10 has an open bug for coverage reports that requires a *terrible* hack
# to workaround. See https://github.com/golang/go/issues/23883 for more details
function generate_dummy_coverage_file() {
  local package_name=$1
  local build_tag=$2
go list ./$FIND_ROOT/... | grep -v vendor | grep -v "\/main$" | grep -v "\/${package_name}" > repo_packages.out
INPUT_FILE=./repo_packages.out python <<END
import os
input_file_path = os.environ['INPUT_FILE']
input_file = open(input_file_path)
print '// +build ${build_tag}'
print
print 'package ${package_name}'
print
print 'import ('
for line in input_file.readlines():
    line = line.strip()
    print '\t _ "%s"' % line
print ')'
print
END
}

export -f generate_dummy_coverage_file

# pick_subset takes a space separated string and breaks it up into multiple subsets.
# $1: " " seperated string,
# $2: name of the variable to store the output in,
# $3: subset index,
# $4: number of total subsets,
# e.g.
# for i in 0 1 2; do echo "## i: $i"; pick_subset "a b c d"  result $i 3 ; echo "$result"; done
#   ## i: 0
#   c
#   ## i: 1
#   a d
#   ## i: 2
#   b
# NB: generated subsets do not necessarily get grouped in the same order as the original list
# (as seen in the example above)

function pick_subset()
{
  local input_to_split=$1
  local __result=$2
  local split_num=$3
  local split_total=$4

  # defaulting to doing the sane thing w/o a warning
  if [ -z $split_num ] &&
     [ -z $split_total ] ; then
    eval $__result="'$input_to_split'"
    return 0
  fi

  local split_output
  if [[ $split_num =~ ^[0-9]+$ ]] &&
     [[ $split_total =~ ^[0-9]+$ ]]   &&
     (( split_num < split_total )) ; then
       split_output=$(echo $input_to_split       \
         | tr ' ' '\n'                           \
         | sort                                  \
         | awk "NR%${split_total}==${split_num}" \
         | tr '\n' ' '                           \
       )
  else
      echo "warning: illegal subset options: "  >&2
      echo "split_num:      ${split_num}"       >&2
      echo "split_total:    ${split_total}"     >&2
      echo "returning full output."             >&2
  fi
  split_output=${split_output:-$input_to_split}
  eval $__result="'$split_output'"
 }

export -f pick_subset
