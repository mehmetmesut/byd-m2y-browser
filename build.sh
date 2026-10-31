#!/usr/bin/env bash
# Modified 2026-10 by Yeşil Dönüşüm Mühendisi - M2Y: Cromite patch set, M2Y layer, relay fixes (GPL-3.0, see LICENSE.md)
# M2Y Browser: Chromium (Cromite's tag) + Cromite patch set + M2Y edits, built in relay stages.
# Derived from ungoogled-chromium-android's build.sh (GPL-3.0); the staging/resume mechanics are kept as they were.
set -eu -o pipefail

source .build_config

pwd
whoami
echo "$PATH"
echo "$HOME"

! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo 'getopt --test failed in this environment.'
    exit 1
fi

OPTIONS=dipra:t:u
LONGOPTS=debug,install-deps,prepare-only,resume,update,arch:,target:

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 2
fi
eval set -- "$PARSED"

ARCH=- TARGET=- DEBUG=n INSTALL_DEPS=n PREPARE_ONLY=n RESUME=n UPDATE=n

while true; do
    case "$1" in
        -d|--debug) DEBUG=y; shift ;;
        -i|--install-deps) INSTALL_DEPS=y; shift ;;
        -p|--prepare-only) PREPARE_ONLY=y; shift ;;
        -r|--resume) RESUME=y; shift ;;
        -u|--update) UPDATE=y; shift ;;  # with --resume: re-apply changed M2Y edits on a finished tree
        -a|--arch) ARCH="$2"; shift 2 ;;
        -t|--target) TARGET="$2"; shift 2 ;;
        --) shift; break ;;
        *) echo "Programming error"; exit 3 ;;
    esac
done

if [[ "$ARCH" != "arm64" ]] && [[ "$ARCH" != "arm" ]] && [[ "$ARCH" != "x64" ]]; then # x64: emulator test builds only
    echo "Wrong architecture"
    exit 4
fi
if [[ "$TARGET" != "chrome_modern_target" ]] && [[ "$TARGET" != "webview_target" ]]; then
    echo "Wrong target"
    exit 5
fi
if [ "$UPDATE" = y ] && [ "$RESUME" != y ]; then
    echo "--update works on a restored tree: use it together with --resume"
    exit 5
fi
TARGET_EXPANDED=${!TARGET}
M2Y_VERSION="${chromium_version}-m2y${m2y_revision}"

echo "arch: $ARCH, target: $TARGET -> ${TARGET_EXPANDED}, version: ${M2Y_VERSION}, debug: $DEBUG"

path_modified=false

function prepare_repos {
  git config --global http.lowSpeedLimit 1000
  git config --global http.lowSpeedTime 900

  declare -a arr=("depot_tools" "src" "cromite" ".cipd")
  for dname in "${arr[@]}"
  do
    if [[ -d "$dname" ]]
    then
      echo "Removing $dname"
      rm -rf "$dname"
    fi
  done

  path_modified=false

  ## Cromite patch set, pinned to the commit its Chromium tag was released from
  mkdir -p cromite
  pushd cromite
  git init -q
  git remote add origin "${cromite_repo}"
  git fetch --depth 1 --no-tags origin "${cromite_commit}" || { popd; return 1; }
  git checkout -q FETCH_HEAD
  popd
  if [ "$(cat cromite/build/RELEASE)" != "${chromium_version}" ]; then
    echo "FATAL: cromite/build/RELEASE is $(cat cromite/build/RELEASE) but .build_config says ${chromium_version}"
    return 1
  fi

  CHROMIUM_SOURCE="${CHROMIUM_SOURCE:-https://chromium.googlesource.com/chromium/src.git}"
  mkdir -p src
  pushd src
  git init -q
  git remote add origin "${CHROMIUM_SOURCE}" 2>/dev/null || git remote set-url origin "${CHROMIUM_SOURCE}"
  case "${CHROMIUM_SOURCE}" in
    *github.com*) _alt="https://chromium.googlesource.com/chromium/src.git" ;;
    *)            _alt="https://github.com/chromium/chromium.git" ;;
  esac
  git fetch --depth 1 --no-tags "${CHROMIUM_SOURCE}" \
      "+refs/tags/${chromium_version}:refs/tags/${chromium_version}" \
    || { echo "primary source failed, falling back to ${_alt}"
         git remote set-url origin "${_alt}"
         git fetch --depth 1 --no-tags "${_alt}" \
             "+refs/tags/${chromium_version}:refs/tags/${chromium_version}"; } \
    || { popd; return 1; }
  git checkout -q "${chromium_version}" || { popd; return 1; }
  popd

  ## Fetch depot-tools
  depot_tools_commit=$(grep 'depot_tools.git' src/DEPS | cut -d\' -f8)
  mkdir -p depot_tools
  pushd depot_tools
  git init
  git remote add origin https://chromium.googlesource.com/chromium/tools/depot_tools.git
  git fetch --depth 1 --no-tags origin "${depot_tools_commit}" || return $?
  git reset --hard FETCH_HEAD
  popd
  OLD_PATH=$PATH
  export PATH="$(pwd -P)/depot_tools:$PATH"
  export PYTHONPATH="$(pwd -P)/depot_tools${PYTHONPATH:+:$PYTHONPATH}"
  path_modified=true
  pushd src/third_party
  ln -sfn ../../depot_tools
  popd

  git config --global http.lowSpeedTime 120
  DEPOT_TOOLS_UPDATE=0 gclient sync -D --no-history --nohooks --shallow
  _sync_rc=$?
  git config --global http.lowSpeedTime 900
  [ $_sync_rc -eq 0 ] || return $_sync_rc

  ( src/third_party/node/update_npm_deps ) || return $?
  _rollup_pkg="src/third_party/devtools-frontend/src/node_modules/rollup/package.json"
  if [ -f "${_rollup_pkg}" ]; then
    ROLLUP_VER=$(grep '"version"' "${_rollup_pkg}" | head -1 | cut -d'"' -f4)
    _rollup_dest="src/third_party/devtools-frontend/src/node_modules/@rollup/rollup-linux-x64-gnu"
    if [ ! -f "${_rollup_dest}/rollup.linux-x64-gnu.node" ]; then
      curl -sL "https://registry.npmjs.org/@rollup/rollup-linux-x64-gnu/-/rollup-linux-x64-gnu-${ROLLUP_VER}.tgz" -o /tmp/rollup-native.tgz || return $?
      rm -rf "${_rollup_dest}"; mkdir -p "${_rollup_dest}"
      tar xzf /tmp/rollup-native.tgz -C "${_rollup_dest}" --strip-components=1 || return $?
    fi
    [ -f "${_rollup_dest}/rollup.linux-x64-gnu.node" ] || { echo "FATAL: rollup native module missing"; return 1; }
  fi

  python3 src/build/util/lastchange.py -o src/build/util/LASTCHANGE
  python3 src/tools/download_optimization_profile.py --newest_state=src/chrome/android/profiles/newest.txt --local_state=src/chrome/android/profiles/local.txt --output_name=src/chrome/android/profiles/afdo.prof --gs_url_base=chromeos-prebuilt/afdo-job/llvm || return $?
  python3 src/tools/download_optimization_profile.py --newest_state=src/chrome/android/profiles/arm.newest.txt --local_state=src/chrome/android/profiles/arm.local.txt --output_name=src/chrome/android/profiles/arm.afdo.prof --gs_url_base=chromeos-prebuilt/afdo-job/llvm || return $?
  python3 src/build/util/lastchange.py -m GPU_LISTS_VERSION --revision-id-only --header src/gpu/config/gpu_lists_version.h
  python3 src/build/util/lastchange.py -m SKIA_COMMIT_HASH -s src/third_party/skia --header src/skia/ext/skia_commit_hash.h
  python3 src/build/util/lastchange.py -m DAWN_COMMIT_HASH -s src/third_party/dawn --revision src/gpu/webgpu/DAWN_VERSION --header src/gpu/webgpu/dawn_commit_hash.h
  python3 src/tools/clang/scripts/update.py
  python3 src/build/linux/sysroot_scripts/install-sysroot.py --arch=amd64
  python3 src/build/linux/sysroot_scripts/install-sysroot.py --arch=i386
  python3 src/v8/tools/builtins-pgo/download_profiles.py download --depot-tools "$(pwd -P)/depot_tools" --check-v8-revision --quiet || return $?
  # PGO (Cromite: chrome_pgo_phase = 2): arm64 reads chrome/android/orderfiles/arm64 (a DEPS package); its arm32
  # side toolchain needs the public android-arm32 profile from Cloud Storage
  python3 src/tools/update_pgo_profiles.py --target=android-arm32 update --gs-url-base=chromium-optimization-profiles/pgo_profiles || return $?
}

function reverse_change {
  if [ "$path_modified" = true ] ; then
    export PATH=$OLD_PATH
    path_modified=false
  fi
}

output_folder="out/Default"
stamp_file="src/${output_folder}/.build-stamp"

build_fingerprint() {
  printf '%s\n' "${M2Y_VERSION}-${cromite_commit}"
  cat m2y/apply.sh m2y/skip_patches.txt m2y.gn_args build.sh .build_config .gclient $(find m2y/res -type f | sort) 2>/dev/null | sha256sum | cut -d' ' -f1
}

# What an --update may not change: the Chromium tag and the Cromite patch set the tree was patched with
base_fingerprint() {
  printf '%s\n' "${chromium_version}-${cromite_commit}"
  cat m2y/skip_patches.txt .gclient 2>/dev/null | sha256sum | cut -d' ' -f1
}

m2y_edit() {
  m2y/apply.sh src
  ( cd src && git add -A && git commit -q -m "M2Y Browser edits (m2y/apply.sh)" )
}

configure() {
  export PATH=${OLD_PATH:-$PATH}  # remove depot_tools from PATH (an --update never put it there)
  pushd src
  mkdir -p "${output_folder}"
  {
    # target_os first: cromite.gn_args branches on it
    printf 'target_os="android"\ntarget_cpu="%s"\n\n' "$ARCH"
    cat ../cromite/build/cromite.gn_args
    printf '\n'
    cat ../m2y.gn_args
    printf '\nandroid_override_version_name="%s"\n' "${M2Y_VERSION}"
    if [ "$DEBUG" = y ]; then printf 'is_debug=true\nis_official_build=false\n'; fi
  } > "${output_folder}/args.gn"
  buildtools/linux64/gn gen "${output_folder}" --fail-on-unused-args
  popd
}

write_stamp() {
  { echo "build      $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "version    ${M2Y_VERSION}"
    echo "cromite    ${cromite_commit}"
    echo "commit     $(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "fingerprint $(build_fingerprint | sha256sum | cut -d' ' -f1)"
    echo "base       $(base_fingerprint | sha256sum | cut -d' ' -f1)"
    echo "session    $(date -u +%Y-%m-%dT%H:%M:%SZ)  run ${GITHUB_RUN_NUMBER:-local}  $1"
  } > "$stamp_file"
}

if [ "$RESUME" = y ]; then
    if [ ! -f "$stamp_file" ] || [ ! -f "src/out/Default/args.gn" ] || [ ! -d "src/third_party" ]; then
        echo "FATAL: --resume but the build tree is incomplete."
        echo "  stamp:      $([ -f "$stamp_file" ] && echo present || echo MISSING)"
        echo "  args.gn:    $([ -f src/out/Default/args.gn ] && echo present || echo MISSING)"
        echo "  src tree:   $([ -d src/third_party ] && echo present || echo MISSING)"
        exit 7
    fi
    want=$(build_fingerprint | sha256sum | cut -d' ' -f1)
    have=$(grep -m1 '^fingerprint ' "$stamp_file" | awk '{print $2}')
    if [ "$UPDATE" = y ] && [ "$want" != "$have" ]; then
        base_want=$(base_fingerprint | sha256sum | cut -d' ' -f1)
        base_have=$(grep -m1 '^base ' "$stamp_file" | awk '{print $2}')
        if [ "$base_want" != "$base_have" ]; then
            echo "FATAL: --update needs the Chromium tag and Cromite patch set of the tree (stamped base: ${base_have:-none}); run a clean build."
            exit 12
        fi
        echo "=== updating the M2Y layer of a stamped tree ==="
        cat "$stamp_file"
    elif [ "$want" != "$have" ]; then
        echo "FATAL: inputs changed since this build was stamped - resuming would mix old and new objects."
        echo "  stamped:  $have"
        echo "  current:  $want"
        exit 8
    fi
    echo "=== resuming verified build ==="
    cat "$stamp_file"
    printf 'session    %s  run %s  resumed at %s objects\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${GITHUB_RUN_NUMBER:-local}" \
        "$(find src/out/Default -name '*.o' 2>/dev/null | wc -l)" >> "$stamp_file"
else
    for i in $(seq 1 10); do prepare_repos && s=0 && break || s=$? && reverse_change && sleep 120; done; (exit $s)
fi

if [ "$INSTALL_DEPS" = y ]; then
    export DEBIAN_FRONTEND=noninteractive
    if ! command -v apt-get >/dev/null 2>&1; then
        echo "FATAL: --install-deps needs apt (Chromium's install-build-deps supports Debian/Ubuntu only)."
        exit 9
    fi
    if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        echo "FATAL: --install-deps needs root or passwordless sudo."
        exit 6
    fi
    apt-get -qq install -y lsb-release file 2>/dev/null \
        || sudo -n apt-get -qq install -y lsb-release file
    ( cd src && ./build/install-build-deps.sh --no-prompt --android --unsupported ) || exit $?
fi

dependencies=(patch ccache zip python3 perl)
missing=()
for dependency in "${dependencies[@]}"; do
    command -v "$dependency" >/dev/null 2>&1 || missing+=("$dependency")
done
if [ ${#missing[@]} -ne 0 ]; then
    echo "FATAL: missing required tools: ${missing[*]}"
    exit 10
fi

if [ "$RESUME" != y ]; then
  ## Cromite patches (git am, as Cromite's own build does)
  pushd src
  git config user.email "ci@m2y.invalid"
  git config user.name "M2Y CI"
  # Cromite patches also touch these nested checkouts; fold them into the main repo so `git am` can reach them.
  for sub in v8 third_party/devtools-frontend/src third_party/skia third_party/perfetto third_party/boringssl/src; do
    if [ -e "$sub/.git" ]; then
      echo "flattening $sub"
      rm -rf "$sub/.git"
      git rm -q -r --cached "$sub" 2>/dev/null || true
      git add -f "$sub"
    fi
  done
  git commit -q -m "M2Y: flatten nested checkouts" || true

  mapfile -t PATCHES < <(grep -vE '^\s*(#|$)' ../cromite/build/cromite_patches_list.txt)
  n=0
  for p in "${PATCHES[@]}"; do
    if grep -qxF "$p" ../m2y/skip_patches.txt 2>/dev/null; then
      echo "skip   $p"
      continue
    fi
    n=$((n+1))
    echo "[$n/${#PATCHES[@]}] $p"
    if ! git am --whitespace=nowarn -q "../cromite/build/patches/$p"; then
      echo "FATAL: Cromite patch failed: $p"
      git am --show-current-patch=diff 2>/dev/null | head -40
      exit 11
    fi
  done
  popd

  m2y_edit
  configure
  write_stamp "clean start"
fi

if [ "$UPDATE" = y ] && [ "$want" != "$have" ]; then
  # The tree's last commit is the previous M2Y edit: back to the Cromite state, then the current m2y/apply.sh.
  # Files whose content comes out the same get their old mtime back, so ninja rebuilds only what really changed.
  pushd src
  git config core.checkStat minimal  # a restored tree has new inodes/ctimes; mtime and size still match the index
  git config core.trustctime false
  [ "$(git log -1 --format=%s)" = "M2Y Browser edits (m2y/apply.sh)" ] || { echo "FATAL: the tree's last commit is not the M2Y edit"; exit 13; }
  declare -A old_sum old_mtime
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    old_sum[$f]=$(sha256sum < "$f")
    old_mtime[$f]=$(stat -c %Y "$f")
  done < <(git diff --name-only HEAD~1 HEAD)
  # Undo only what apply.sh modified or deleted: the edit commit also swept in untracked files present at prep time
  # (the third_party/depot_tools link, downloaded profiles), and a hard reset would delete them
  # shortcut: a file an older apply.sh created stays on disk, remove it by hand if apply.sh stops creating it
  mapfile -t _back < <(git diff --name-only --diff-filter=MD HEAD~1 HEAD)
  git reset -q --mixed HEAD~1
  [ ${#_back[@]} -eq 0 ] || git checkout -q HEAD -- "${_back[@]}"
  popd
  m2y_edit
  pushd src
  kept=0
  for f in "${!old_sum[@]}"; do
    if [ -f "$f" ] && [ "$(sha256sum < "$f")" = "${old_sum[$f]}" ]; then
      touch -m -d "@${old_mtime[$f]}" "$f"
      kept=$((kept+1))
    fi
  done
  echo "M2Y layer: ${#old_sum[@]} files in the previous edit, ${kept} unchanged; $(git diff --name-only HEAD~1 HEAD | wc -l) files now"
  popd
  configure
  write_stamp "updated M2Y layer"
fi

if [ "$PREPARE_ONLY" = y ]; then
    cat "$stamp_file"
    echo "prepare complete, stopping before ninja"
    exit 0
fi

## Set compiler flags
export AR=${AR:=llvm-ar}
export NM=${NM:=llvm-nm}
export CC=${CC:=clang}
export CXX=${CXX:=clang++}
export CCACHE_CPP2=yes
export CCACHE_SLOPPINESS=time_macros

## Build
case "${NINJA_JOBS:-0}" in
    ''|*[!0-9]*) NINJA_JOBS=0 ;;
esac
if [ "${NINJA_JOBS:-0}" -eq 0 ]; then
    NINJA_JOBS=$(nproc)
fi

ninja_build() {
  _dir="$1"
  shift
  if [ -z "${NINJA_TIMEOUT:-}" ]; then
    "$ninja_bin" ${NINJA_JOBS:+-j ${NINJA_JOBS}} -C "$_dir" "$@"
    return
  fi
  _rc=0
  timeout -k 5m -s INT "$NINJA_TIMEOUT" \
    "$ninja_bin" ${NINJA_JOBS:+-j ${NINJA_JOBS}} -C "$_dir" "$@" || _rc=$?
  if [ "$_rc" = 124 ] || [ "$_rc" = 137 ]; then
    echo "ninja reached the ${NINJA_TIMEOUT} budget with work remaining"
    echo "status=running" >> "${GITHUB_OUTPUT:-/dev/null}"
    exit 0
  fi
  return $_rc
}

apk_out_folder="apk_out"
mkdir -p "${apk_out_folder}"
pushd src
ninja_bin="third_party/ninja/ninja"
ninja_build "${output_folder}" "${TARGET_EXPANDED}"
if [ "${TARGET_EXPANDED}" = "chrome_public_apk" ]; then
  cp -f "${output_folder}/apks/ChromePublic.apk" "../${apk_out_folder}/M2YBrowser_${M2Y_VERSION}_${ARCH}.apk"
else
  find "${output_folder}/apks" -maxdepth 1 -iname "*.apk" -exec cp -f {} "../${apk_out_folder}" \;
fi
popd

printf 'session    %s  run %s  BUILD COMPLETE\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${GITHUB_RUN_NUMBER:-local}" >> "$stamp_file"
echo "status=completed" >> "${GITHUB_OUTPUT:-/dev/null}"
echo "=== build provenance ==="
cat "$stamp_file"
ls -l "${apk_out_folder}"
