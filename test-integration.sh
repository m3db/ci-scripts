#!/bin/bash
set -e

source "$(dirname $0)/variables.sh"

COVERFILE=${1:-profile.cov}
EXCLUDE_FILE=${2}
TAGS="integration"
DIR="integration"
INTEGRATION_TIMEOUT=${INTEGRATION_TIMEOUT:-10m}
COVERMODE=atomic
SCRATCH_FILE=${COVERFILE}.tmp
SRC_ROOT=${SRC_ROOT:-.}
RACE=${RACE:-""}
TEST_OPTS=()

if [ ! -d "${SRC_ROOT}/${DIR}" ]; then
  echo "No integrations tests found"
  exit 0
fi

echo "mode: ${COVERMODE}" > $SCRATCH_FILE

# go1.10 has an open bug for coverage reports that requires a *terrible* hack
# to workaround. See https://github.com/golang/go/issues/23883 for more details
GO_MINOR_VERSION=$(go version | awk '{print $3}' | cut -d '.' -f 2)
if [ ${GO_MINOR_VERSION} -ge 10 ]; # i.e. we're on go1.10 and up
then
  echo "Generating dummy integration file with all the packages listed for coverage"
  DUMMY_FILE_PATH=${SRC_ROOT}/integration/coverage_imports.go
  if [ -f ${DUMMY_FILE_PATH} ]; then
    rm -f ${DUMMY_FILE_PATH} # delete file if it exists (only happens when running on a laptop)
  fi
  # NB: need to do this in two steps or the go compiler compiles the partial file and is :(
  generate_dummy_coverage_file integration integration > coverage_imports_file.out
  mv coverage_imports_file.out ${DUMMY_FILE_PATH}
fi

if [ -n "${RACE}" ]; then
  TEST_OPTS+=("-race")
fi

# compile the integration test binary
go test "${TEST_OPTS[@]}" -c -tags ${TAGS} -covermode ${COVERMODE} \
  -coverpkg $(go list ./$SRC_ROOT/... |  grep -v /vendor/ | paste -sd, -) ${SRC_ROOT}/${DIR}

INTEGRATION_TEST="./integration.test"

# Handle subdirectories with no integration tests
if [ ! -f ${INTEGRATION_TEST} ]; then
  echo "No integrations tests found"
  exit 0
fi

ALL_TESTS=$(./integration.test -test.list '.*')
# defaults to all if the split vars are unset
pick_subset "$ALL_TESTS" TESTS $SPLIT_IDX $TOTAL_SPLITS

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
