#!/bin/sh
# Run the test suite in a Debian container with the working tree as it is now.
#
#   sh tests/docker.sh
set -eu

REPO=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
docker run --rm -v "$REPO":/repo:ro python:3.12-slim-bookworm sh -c '
apt-get -qq update >/dev/null 2>&1
apt-get -qq install -y --no-install-recommends bash curl jq make >/dev/null 2>&1
cp -R /repo /tmp/td && cd /tmp/td && make test
'
