#!/bin/sh

PROJECT_PACKAGE=$1

if [ "$PROJECT_PACKAGE" = "" ]; then
    echo "Missing project package as first arg to $0"
    exit 1
fi

GIT_REVISION=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo unknown)
BUILD_DATE=$(date '+%F-%T') # outputs something in this format 2017-08-21-18:58:45
BASE_PACKAGE=${PROJECT_PACKAGE}/vendor/github.com/m3db/m3x/instrument

LD_FLAGS="-X ${BASE_PACKAGE}.Revision=${GIT_REVISION} \
-X ${BASE_PACKAGE}.Branch=${GIT_BRANCH}    \
-X ${BASE_PACKAGE}.Version=${GIT_VERSION}  \
-X ${BASE_PACKAGE}.BuildDate=${BUILD_DATE} \
-X ${BASE_PACKAGE}.LogBuildInfoAtStartup=true"

echo $LD_FLAGS
