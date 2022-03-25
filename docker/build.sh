#!/bin/bash

# This script creates builds according to our custom build policy, which is:
# - "master" will always point to the most recent build on master
# - "latest" will refer to the latest tagged release
# - Each release "foo" will have a tag "foo"
#
# This script is a noop if HEAD is not origin/master OR tagged.

set -exo pipefail

CONFIG=${1:-"docker/images.json"}

function cleanup() {
  docker system prune -f
  # We may not have permissions to clean /tmp in some environments.
  if [[ -n "$DO_TMP_CLEANUP" ]]; then
    find /tmp -name '*m3-docker' -print0 | xargs -0 rm -fv
  fi
}

trap cleanup EXIT

# The logs for builds have a ton of output from set -x, Docker builds, etc. Need
# an easy way to find our own messages in the logs.
function log_info() {
  echo "[INFO] $1"
}

function push_image() {
  if [[ -z "$DRYRUN" ]]; then
    log_info "pushing $1"
    docker push "$1"
  else
    echo "would push $1"
  fi
}

function do_jq() {
  <"$CONFIG" jq -er "$1"
}

# Allow null key values (useful for optional fields)
function do_jq_null() {
  <"$CONFIG" jq -r "$1"
}

if [[ ! -f "$CONFIG" ]]; then
  echo "could not find docker images config $CONFIG"
  exit 1
fi

if [[ -z "$M3_DOCKER_REPO" ]]; then
  echo "must set M3_DOCKER_REPO to repository base (i.e quay.io/m3)"
  exit 1
fi

IMAGES="$(do_jq '.images | to_entries | map(.key)[]')"
REPO=$M3_DOCKER_REPO
TAGS_TO_PUSH=""

# If this commit matches an exact tag, push a tagged build and "latest".
if git describe --tags --exact-match; then
  TAG=$(git describe --tags --exact-match)
  TAGS_TO_PUSH="${TAGS_TO_PUSH} ${TAG}"
  # Don't tag latest if this is a pre-release.
  if ! <<<"$TAG" grep -Eq "alpha|beta|rc"; then
    TAGS_TO_PUSH="${TAGS_TO_PUSH} latest"
  fi
fi

# If this commit says to do a docker build, push a tag with the branch name.
if [[ "$BUILDKITE_MESSAGE" =~ /build-docker ]]; then
  # Sanitize the branch name (any non-alphanum char gets turned into a '_').
  TAG=$(<<<"$BUILDKITE_BRANCH" sed 's/[^a-z|0-9]/_/g')
  TAGS_TO_PUSH="${TAGS_TO_PUSH} ${TAG}"
fi

CURRENT_SHA=$(git rev-parse HEAD)
MASTER_SHA=$(git rev-parse origin/master)

# If the current commit is exactly origin/master, push a tag for "master".
if [[ "$CURRENT_SHA" == "$MASTER_SHA" ]]; then
  TAGS_TO_PUSH="${TAGS_TO_PUSH} master"
fi

if [[ -z "$TAGS_TO_PUSH" ]]; then
  exit 0
fi

log_info "will push [$TAGS_TO_PUSH]"

for IMAGE in $IMAGES; do
  NAME=$(do_jq ".images[\"${IMAGE}\"].name")
  TAG_SUFFIX=$(do_jq_null ".images[\"${IMAGE}\"].tag_suffix")
  SHA_TMP=$(mktemp --suffix m3-docker)

  # Do one build, then push all the necessary tags.
  log_info "building $NAME ($IMAGE)"
  docker buildx build \
    --iidfile "$SHA_TMP"
    --builder multi-platform-builder \
    --platform linux/amd64,linux/arm64 \
    -f "$(do_jq ".images[\"${IMAGE}\"].dockerfile")" .
  IMAGE_SHA=$(cat "$SHA_TMP")

  for TAG in $TAGS_TO_PUSH; do
    # jq outputs "null" for null values. If we ever have a tag suffixed named
    # "null" we'll have to change this.
    if [[ "$TAG_SUFFIX" != "null" ]]; then
      TAG="${TAG}-${TAG_SUFFIX}"
    fi
    FULL_TAG="${REPO}/${NAME}:${TAG}"
    docker tag "$IMAGE_SHA" "$FULL_TAG"
    push_image "$FULL_TAG"
  done
done

# Clean up
CLEANUP_IMAGES=$(docker images | grep "$REPO" | awk '{print $3}' | sort | uniq)
for IMG in $CLEANUP_IMAGES; do
  log_info "removing $IMG"
  docker rmi -f "$IMG"
done
