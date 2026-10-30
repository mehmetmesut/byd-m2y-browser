#!/usr/bin/env bash
set -euo pipefail

_out="${GITHUB_WORKSPACE}/build-tree.tar.zst"
rm -f "$_out"

echo "::group::packing build tree"
# src/.git stays: an --update resets the previous M2Y commit before applying the current m2y/apply.sh
( cd "${UGC_WORK}" && tar --format=posix -cf - \
      $(for d in src depot_tools cromite .cipd; do [ -e "$d" ] && printf '%s ' "$d"; done) ) \
  | zstd -T0 -3 -o "$_out"
ls -lh "$_out" | sed 's/^/  /'
echo "::endgroup::"

df -h / /mnt
