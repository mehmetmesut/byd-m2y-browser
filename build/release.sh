#!/usr/bin/env bash
# Collect the finished APK into releases/<version>/. Signing happens outside the cloud, with the M2Y key.
set -eu
cd "$(dirname "$0")/.."
. ./.build_config
REL="releases/${chromium_version}-m2y${m2y_revision}"
mkdir -p "$REL"
cp -f apk_out/*.apk "$REL/"
ls -l "$REL"
