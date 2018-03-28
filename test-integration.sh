#!/bin/bash
set -e

source "$(dirname $0)/variables.sh"

COVERFILE=${1:-profile.cov}
EXCLUDE_FILE=${2}
TAGS="integration"
DIR="integration"
INTEGRATION_TIMEOUT=${INTEGRATION_TIMEOUT:-10m}
COVERMODE=count
SCRATCH_FILE=${COVERFILE}.tmp

echo "mode: ${COVERMODE}" > $SCRATCH_FILE

# compile the integration test binary
go test -test.c -test.tags=${TAGS} -test.covermode ${COVERMODE} \
  -test.coverpkg $(go list ./... |  grep -v /vendor/ | paste -sd, -) ./${DIR}

# list the tests
TESTS=$(./integration.test -test.v -test.short | grep RUN | tr -s " " | cut -d ' ' -f 3)
# can use the version below once the minimum version we use is go1.9
# TESTS=$(./integration.test -test.list '.*')

# execute tests one by one for isolation
for TEST in $TESTS; do
  ./integration.test -test.v -test.run $TEST -test.coverprofile temp_${COVERFILE} \
  -test.timeout $INTEGRATION_TIMEOUT ./integration
  TEST_EXIT=$?
  if [ "$TEST_EXIT" != "0" ]; then
    echo "$TEST failed"
    exit $TEST_EXIT
  fi
  cat temp_${COVERFILE} | grep -v "mode:" >> ${SCRATCH_FILE}
  sleep 0.1
done

filter_cover_profile $SCRATCH_FILE $COVERFILE $EXCLUDE_FILE

echo "PASS all integrations tests"
