# M3 Docker Builds

M3 docker images are built according to the following policy:

1. For all images, `${IMAGE}:master` will point to the latest build on `origin/master` for that image.

2. For all images, `${IMAGE}:latest` will point to the latest tagged release.

3. For all images, and for all releases, there will be an image tagged `${IMAGE}:${RELEASE}`.

## Builds

This directory contains the  build scripts for building images according to the above policy, and is intended to be
called when `ci-scripts` is a submodule of another repo. The script requires an `images.json` to be passed as the first
arg to `build.sh`, however if unset will default to `docker/images.json`. The script requires a Buildkite docker
pipeline at `.buildkite/image-release-pipeline.yml` of the calling repo.

`images.json` has the config for each image, and the base
repository comes from the environment variable `M3_DOCKER_REPO`. For example, with the following config:

```
export M3_DOCKER_REPO=quay.io/m3
```

```json
{
  "images": {
    "m3dbnode": {
      "dockerfile": "docker/m3dbnode/Dockerfile",
      "aliases": [
        "m3db"
      ]
    }
  }
}
```

`quay.io/m3/m3dbnode` will be dual-published under `quay.io/m3/m3dbnode:latest` and `quay.io/m3/m3db:latest` for
the latest release.
