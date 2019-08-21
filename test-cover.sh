#!/bin/bash
set -e

source "$(dirname $0)/variables.sh"

TARGET=${1:-profile.cov}
EXCLUDE_FILE=${2:-.excludecoverage}
LOG=${3:-test.log}
CI_DIR=${4:-.}

rm -f "$TARGET" &>/dev/null || true

DIRS=""
for DIR in $SRC;
do
  if ls $DIR/*_test.go &> /dev/null; then
    DIRS="$DIRS $DIR"
  fi
done

# defaults to all DIRS if the split vars are unset
pick_subset "$DIRS" TESTS "$SPLIT_IDX" "$TOTAL_SPLITS"

if [ "$NPROC" = "" ]; then
  NPROC=$(getconf _NPROCESSORS_ONLN)
fi

echo "test-cover begin: concurrency $NPROC"

PROFILE_REG="profile_reg.tmp"

echo 'mode: atomic' > "$TARGET"
echo "" > "$LOG"
<<<"$TESTS" xargs -P $NPROC -n1 -I{} sh -c "go test -v -race -timeout 5m -covermode=atomic -coverprofile=${PROFILE_REG} {} && tail -n +2 $PROFILE_REG >> $TARGET"
TEST_EXIT=$?

filter_cover_profile $PROFILE_REG "$TARGET" "$EXCLUDE_FILE"

find . -not -path '*/vendor/*' | grep \\.tmp$ | xargs -I{} rm {}
echo "test-cover result: $TEST_EXIT"

exit "$TEST_EXIT"
