#!/bin/bash
. "$(dirname $0)/variables.sh"

set -e

TAGS="integration"
DIR="integration"
INTEGRATION_TIMEOUT=${INTEGRATION_TIMEOUT:-10m}
COVERFILE=${COVERFILE:-cover.out}
COVERMODE=count

echo "mode: ${COVERMODE}" > $COVERFILE

# compile the integration test binary
go test -test.c -test.tags=${TAGS} -test.covermode ${COVERMODE} \
  -test.coverpkg $(go list ./... | paste -sd, -) ./${DIR}

# list the tests
TESTS=$(./integration.test -test.list '.*')

# execute tests one by one for isolation
for TEST in $TESTS; do
  ./integration.test -test.v -test.run $TEST -test.coverprofile temp_${COVERFILE} \
  -test.timeout $INTEGRATION_TIMEOUT ./integration
  TEST_EXIT=$?
  if [ "$TEST_EXIT" != "0" ]; then
    echo "$TEST failed"
    exit $TEST_EXIT
  fi
  cat temp_${COVERFILE} | grep -v '_mock.go' | grep -v "mode: " >> ${COVERFILE}
  sleep 0.1
done

echo "PASS all integrations tests"
