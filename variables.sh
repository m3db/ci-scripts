#!/bin/bash

# set PACKAGE in .travis.yml
export VENDOR_PATH=$PACKAGE/vendor
export LICENSE_BIN=$GOPATH/src/$PACKAGE/.ci/uber-licence/bin/licence
export GO15VENDOREXPERIMENT=1
export SRC=$(find ./ -maxdepth 10 -not -path '*/.git*' -not -path '*/.ci*' -not -path '*/_*' -not -path '*/vendor/*' -type d)

# pick_subset
# $1: " " seperated string
# $2: subset num
# $3: subset total
# $4: optional result var
# e.g.
#  $ pick_subset "a b c d" 1 3 result
#  $ echo $result
#  a d
function pick_subset()
{
    local input_to_split=$1
    local split_num=$2
    local split_total=$3
    local __result=$4
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
      echo "input_to_split: ${input_to_split}"  >&2
      echo "split_num:      ${split_num}"       >&2
      echo "split_total:    ${split_total}"     >&2
      echo "returning full output."             >&2
      split_output=${input_to_split}
    fi

    if [[ "$__result" ]]; then
        eval $__result="'$split_output'"
    else
        echo "$split_output"
    fi
}