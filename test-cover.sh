#!/bin/bash
. "$(dirname $0)/variables.sh"

set -e

TARGET=${1:-profile.cov}
LOG=${2:-test.log}

rm $TARGET &>/dev/null || true
echo "mode: count" > $TARGET
echo "" > $LOG

DIRS=""
for DIR in $SRC;
do
  if ls $DIR/*_test.go &> /dev/null; then
    DIRS="$DIRS $DIR"
  fi
done

pick_subset "$DIRS" $UNIT_TEST_NUM $UNIT_TEST_TOTAL TESTS

if [ "$NPROC" = "" ]; then
  NPROC=$(getconf _NPROCESSORS_ONLN)
fi

echo "test-cover begin: concurrency $NPROC"
go run .ci/gotestcover/gotestcover.go -timeout 1m -race -covermode=atomic -coverprofile=profile.tmp -v -parallelpackages $NPROC $TESTS | tee $LOG

TEST_EXIT=${PIPESTATUS[0]}

cat profile.tmp | grep -v "_mock.go" > $TARGET

find . -not -path '*/vendor/*' | grep \\.tmp$ | xargs -I{} rm {}
echo "test-cover result: $TEST_EXIT"

exit $TEST_EXIT
