#!/bin/bash
set -e

source "$(dirname $0)/variables.sh"

function bk_log() {
  if [[ "${BUILDKITE}" == "true" ]]; then
    echo "--- $1"
  fi
}

TARGET=${1:-profile.cov}
EXCLUDE_FILE=${2:-.excludecoverage}
LOG=${3:-test.log}

rm $TARGET &>/dev/null || true
echo "mode: atomic" > $TARGET
echo "" > $LOG

DIRS=""
for DIR in $SRC;
do
  if ls $DIR/*_test.go &> /dev/null; then
    DIRS="$DIRS $DIR"
  fi
done

# defaults to all DIRS if the split vars are unset
pick_subset "$DIRS" TESTS $SPLIT_IDX $TOTAL_SPLITS

if [ "$NPROC" = "" ]; then
  NPROC=$(getconf _NPROCESSORS_ONLN)
fi

# Sometimes has a space at the end (i.e. "2 "), regardless of source. Strip all
# spaces.
NPROC=${NPROC// /}

bk_log ":golang: Running tests and coverage"
echo "test-cover begin: concurrency $NPROC"

PROFILE_REG="profile_reg.tmp"

export COVERTMP
COVERTMP="$(mktemp -d)"
rm -rf "$COVERTMP"
mkdir -p "$COVERTMP"

function cleanup {
  rm -rf "$COVERTMP"
}

trap cleanup EXIT

echo 'mode: atomic' > "$TARGET"
echo "" > "$LOG"

# In parallel, write each package's coverage information to a package-specific
# file. Sanitize each package path to a file-friendly name.
set +e
<<<"$TESTS" xargs -P "$NPROC" -n1 .ci/process-cover-package.sh
TEST_EXIT=$?
set -e

FAILED_PKGS=""

# Combine all per-package cover results into one larger result.
while read -r F; do
  if [[ "$(head -c 6 "$F")" == "FAILED" ]]; then
    FAILED_PKGS="${FAILED_PKGS} $(awk '{print $2}' "$F")"
  else
    tail -n +2 "$F" >> "$PROFILE_REG"
  fi
# NB(schallert): see https://github.com/koalaman/shellcheck/wiki/SC2031 for why
# find results are passed at end of loop to preserve FAILED_PKGS
done < <(find "$COVERTMP/" -type f)

filter_cover_profile $PROFILE_REG "$TARGET" "$EXCLUDE_FILE"

find . -not -path '*/vendor/*' | grep \\.tmp$ | xargs -I{} rm {}

if [[ -n "$FAILED_PKGS" ]]; then
  bk_log ":bk-status-failed: encountered package failure(s)"
  echo "packages with failures: [${FAILED_PKGS}]"
fi

echo "test-cover result: $TEST_EXIT"

exit $TEST_EXIT
