#!/bin/bash
set -ex

source "$(dirname $0)/variables.sh"

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

echo "test-cover begin: concurrency $NPROC"

PROFILE_REG="profile_reg.tmp"

# Ideally we'd use $(mktemp -d), but xargs -I{} limits resulting strings to 255
# bytes and some systems (such as MacOS) generate insanely long tmpdir names.
# This makes sure we have better control of the arg length.
export COVERTMP="covertmp"
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
#
# GNU xargs only takes newlines as separator if using -I. Can get around this
# with `-d '\n'`, but that doesn't work on BSD (+MacOS) xargs. Replacing spaces
# with newlines is cross-platform friendly.
echo "$TESTS" | tr ' ' '\n' | xargs -P "$NPROC" -n1 .ci/process-cover-package.sh

TEST_EXIT=$?

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
  echo "packages with failures: [${FAILED_PKGS}]"
fi

echo "test-cover result: $TEST_EXIT"

exit $TEST_EXIT
