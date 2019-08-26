#!/bin/bash
set -ex

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

# Temporary file to store cover results individually before merging (avoid race
# in printing outputs and clobbering test results).
COVER_TMPDIR=cover.tmp
mkdir -p $COVER_TMPDIR

# Output each package's coverage result to a "friendly" file name (anything
# that's not a character gets changed to '_'). Then combine those serially into
# one result to not corrupt test output. Map reduce in bash, yolo.
if [[ "$(uname)" == "Darwin" ]]; then
  echo "$TESTS" | xargs -P $NPROC -n1 -I{} sh -c "set -x; NAME=\$(echo {} | sed 's/[^a-z]/_/g'); go test -v -race -timeout 5m -covermode=atomic -coverprofile=${COVER_TMPDIR}/\$NAME {} | tee -a $LOG"
else
  echo "$TESTS" | xargs -d ' ' -P $NPROC -n1 -I{} sh -c "set -x; NAME=\$(echo {} | sed 's/[^a-z]/_/g'); go test -v -race -timeout 5m -covermode=atomic -coverprofile=${COVER_TMPDIR}/\$NAME {} | tee -a $LOG"
fi

TEST_EXIT=$?

for F in "$COVER_TMPDIR"/*; do
  tail -n +2 "$F" >> "$PROFILE_REG"
done

filter_cover_profile $PROFILE_REG "$TARGET" "$EXCLUDE_FILE"
rm -rf "$COVER_TMPDIR"

echo "test-cover result (results in $TARGET): $TEST_EXIT"
exit "$TEST_EXIT"
