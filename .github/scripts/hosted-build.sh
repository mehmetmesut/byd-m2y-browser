#!/usr/bin/env bash
set -euo pipefail

mkdir -p "${UGC_WORK}"
cp -a "${GITHUB_WORKSPACE}/." "${UGC_WORK}/"

export CCACHE_DIR=/mnt/ccache
cd "${UGC_WORK}"

# M2Y: on a resumed relay part, generate every *buildflags.h first. Some objects in this tree include one
# without depending on it (gpu_service_impl.o -> services/webnn/buildflags.h stopped the first part).
# Kept out of build.sh on purpose: build.sh is part of the resume fingerprint.
if [[ " $* " == *" --resume "* ]] && [ -x src/third_party/ninja/ninja ] && [ -f src/out/Default/args.gn ]; then
  mapfile -t _flag_headers < <(src/third_party/ninja/ninja -C src/out/Default -t targets all 2>/dev/null \
      | grep -oE '^gen/[^:]*buildflags\.h' | sort -u)
  if [ "${#_flag_headers[@]}" -gt 0 ]; then
    echo "pre-generating ${#_flag_headers[@]} buildflags headers"
    src/third_party/ninja/ninja -C src/out/Default "${_flag_headers[@]}"
  fi
fi

: > build-step.log
setsid ./build.sh "$@" < /dev/null >> build-step.log 2>&1 &
_pid=$!
tail --pid="$_pid" -n +1 -f build-step.log &
_tail=$!
_rc=0
wait "$_pid" || _rc=$?
sudo pkill -9 -s "$_pid" 2>/dev/null || true
wait "$_tail" 2>/dev/null || true
exit "$_rc"
