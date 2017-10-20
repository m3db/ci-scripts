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

if [ "$NPROC" = "" ]; then
  NPROC=$(getconf _NPROCESSORS_ONLN)
fi

echo "test-cover begin: concurrency $NPROC"

PROFILE_FINAL="profile.tmp"
PROFILE_NOPARALLEL="profile_noparallel.tmp"

TEST_FLAGS="-v -race -timeout 5m -covermode atomic"
go run .ci/gotestcover/gotestcover.go $TEST_FLAGS -coverprofile $PROFILE_FINAL -parallelpackages $NPROC $DIRS | tee $LOG
TEST_EXIT=${PIPESTATUS[0]}

# run noparallel tests
echo "test-cover begin: concurrency 1, +noparallel"
for DIR in $DIRS; do
  if cat $DIR/*_test.go | grep "// +build" | grep "noparallel" &>/dev/null; then
    go test $TEST_FLAGS -tags noparallel -coverprofile $PROFILE_NOPARALLEL $DIR | tee $LOG
    TEST_EXIT=${PIPESTATUS[0]}
    if [ "$TEST_EXIT" != "0" ]; then
      continue
    fi
    if [ -s $PROFILE_NOPARALLEL ]; then
      cat $PROFILE_NOPARALLEL | tail -n +1 >> $PROFILE_FINAL
    fi
  fi
done

cat $PROFILE_FINAL | grep -v "_mock.go" > $TARGET

find . -not -path '*/vendor/*' | grep \\.tmp$ | xargs -I{} rm {}
echo "test-cover result: $TEST_EXIT"

exit $TEST_EXIT
