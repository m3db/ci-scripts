#!/bin/bash
. "$(dirname $0)/variables.sh"

set -e

TAGS="integration"
DIR="integration"
INTEGRATION_TIMEOUT=${INTEGRATION_TIMEOUT:-10m}

# compile the integration test binary
go test -test.c -test.tags=${TAGS} ./${DIR}

# list the tests
ALL_TESTS=$(./integration.test -test.v -test.short | grep RUN | tr -s " " | cut -d ' ' -f 3)

# pick the subset of tests
pick_subset "$ALL_TESTS" $INTEGRATION_TEST_NUM $INTEGRATION_TEST_TOTAL TESTS

# execute tests one by one for isolation
for TEST in $TESTS; do
  ./integration.test -test.v -test.run $TEST -test.timeout $INTEGRATION_TIMEOUT ./integration
  TEST_EXIT=$?
  if [ "$TEST_EXIT" != "0" ]; then
    echo "$TEST failed"
    exit $TEST_EXIT
  fi
  sleep 0.1
done

echo "PASS all integrations tests"
