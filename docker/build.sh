#!/bin/bash

# This script creates builds according to our custom build policy, which is:
# - "master" will always point to the most recent build on master
# - "latest" will refer to the latest tagged release
# - Each release "foo" will have a tag "foo"
# - If PUSH_SHA_TAG is set to true, the image will be tagged with the first
#   8 characters of the SHA from the commit the image was built from.
# - Images are built as multi-arch manifests for the platforms listed in
#   DOCKER_PLATFORMS (default: linux/amd64,linux/arm64) using docker buildx.
#
# This script is a noop if HEAD is not origin/master OR tagged.

set -exo pipefail

CONFIG=${1:-"docker/images.json"}
PLATFORMS=${DOCKER_PLATFORMS:-"linux/amd64,linux/arm64"}
BUILDER=${DOCKER_BUILDER_NAME:-"m3-multi-platform-builder"}

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

function do_jq() {
  jq <"$CONFIG" -er "$1"
}

# Allow null key values (useful for optional fields)
function do_jq_null() {
  jq <"$CONFIG" -r "$1"
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
  if ! grep <<<"$TAG" -Eq "alpha|beta|rc"; then
    TAGS_TO_PUSH="${TAGS_TO_PUSH} latest"
  fi
fi

# If this commit says to do a docker build, push a tag with the branch name.
if [[ "$BUILDKITE_MESSAGE" =~ /build-docker ]]; then
  # Sanitize the branch name (any non-alphanum char gets turned into a '_').
  TAG=$(sed <<<"$BUILDKITE_BRANCH" 's/[^a-z|0-9]/_/g')
  TAGS_TO_PUSH="${TAGS_TO_PUSH} ${TAG}"
fi

CURRENT_SHA=$(git rev-parse HEAD)
MASTER_SHA=$(git rev-parse origin/master)

# If the current commit is exactly origin/master, push a tag for "master".
if [[ "$CURRENT_SHA" == "$MASTER_SHA" ]]; then
  TAGS_TO_PUSH="${TAGS_TO_PUSH} master"
fi

# Push a tag for with the first 8 characters of the SHA of the commit if the
# caller has set the PUSH_SHA_TAG environment variable to true.
if [[ "${PUSH_SHA_TAG:-false}" == "true" ]]; then
  CURRENT_SHA_SHORT=$(git rev-parse --short=8 HEAD)
  TAGS_TO_PUSH="${TAGS_TO_PUSH} ${CURRENT_SHA_SHORT}"
fi

if [[ -z "$TAGS_TO_PUSH" ]]; then
  exit 0
fi

log_info "will push [$TAGS_TO_PUSH] for platforms [$PLATFORMS]"

# Multi-platform builds need the docker-container buildx driver and binfmt
# handlers for any non-native platform. Register the QEMU handlers (no-op if
# already present) and create the builder if it does not exist yet.
docker run --privileged --rm tonistiigi/binfmt --install all
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  log_info "creating docker builder: $BUILDER"
  docker buildx create --name "$BUILDER" --driver docker-container --bootstrap
fi

for IMAGE in $IMAGES; do
  NAME=$(do_jq ".images[\"${IMAGE}\"].name")
  TAG_SUFFIX=$(do_jq_null ".images[\"${IMAGE}\"].tag_suffix")
  DOCKERFILE=$(do_jq ".images[\"${IMAGE}\"].dockerfile")

  # A multi-platform image cannot be loaded into the local daemon, so instead
  # of build -> tag -> push we do a single build that pushes every tag.
  TAG_ARGS=()
  for TAG in $TAGS_TO_PUSH; do
    # jq outputs "null" for null values. If we ever have a tag suffixed named
    # "null" we'll have to change this.
    if [[ "$TAG_SUFFIX" != "null" ]]; then
      TAG="${TAG}-${TAG_SUFFIX}"
    fi
    TAG_ARGS+=(-t "${REPO}/${NAME}:${TAG}")
  done

  if [[ -z "$DRYRUN" ]]; then
    OUTPUT_ARG="--push"
  else
    echo "would push ${TAG_ARGS[*]}"
    OUTPUT_ARG="--output=type=image,push=false"
  fi

  log_info "building $NAME ($IMAGE)"
  docker buildx build \
    --builder "$BUILDER" \
    --platform "$PLATFORMS" \
    --provenance=false \
    "${TAG_ARGS[@]}" \
    $OUTPUT_ARG \
    -f "$DOCKERFILE" .
done

# Clean up build cache (images never touch the local daemon with buildx --push).
docker buildx prune -f --builder "$BUILDER"
