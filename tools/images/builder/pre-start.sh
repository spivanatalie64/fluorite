#!/bin/bash
# Prepares the patched source image for compilation: warms vpython environments,
# downloads PGO/AFDO profiles and cross toolchains, builds helper tools.
# Everything needed at build time is fetched here so builds can run --offline.
set -e

RED='\033[0;31m'
NC='\033[0m'

WORKSPACE=${WORKSPACE:-/workspace}
TARGET_OS_LIST=${TARGET_OS_LIST:-"android"}
REPO_DIR=${REPO_DIR:-$WORKSPACE/repo}

PATH=$WORKSPACE/chromium/src/third_party/llvm-build/Release+Asserts/bin:$WORKSPACE/depot_tools/:/usr/local/go/bin:$PATH

has_target() { echo " $TARGET_OS_LIST " | grep -q " $1 "; }

if command -v pacman >/dev/null 2>&1; then
  sudo pacman -Syu --noconfirm --needed lsof parallel go
else
  sudo apt-get update && sudo apt-get install -y lsof libgoogle-glog-dev parallel golang-go
fi

echo -e "${RED} -------- download mtool ${NC}"
cd $WORKSPACE
git clone https://github.com/bromite/mtool
cd mtool
# repo predates Go modules; synthesize a module so modern toolchains build it
go mod init mtool
go mod tidy
make
cd ..

echo -e "${RED} -------- download ninjatracing ${NC}"
git clone https://github.com/nico/ninjatracing

export CIPD_CACHE_DIR=$WORKSPACE/.cipd_cache
export VPYTHON_VIRTUALENV_ROOT=$WORKSPACE/vpython_root
mkdir -p $CIPD_CACHE_DIR $VPYTHON_VIRTUALENV_ROOT

echo -e "${RED} -------- prepare vpython virtual environment ${NC}"
cd $WORKSPACE/chromium/src
for spec in .vpython3 ../../depot_tools/.vpython3 third_party/angle/.vpython3 \
            third_party/catapult/.vpython3 third_party/webrtc/.vpython3 \
            v8/.vpython3 v8/tools/.vpython3 tools/flags/.vpython3; do
  vpython3 -vpython-spec $spec -vpython-root $VPYTHON_VIRTUALENV_ROOT -vpython-tool install
done

echo -e "${RED} -------- rollup devtools-frontend third_party ${NC}"
cd $WORKSPACE/chromium/src/third_party/devtools-frontend/src
vpython3 scripts/deps/sync_rollup_libs.py

echo -e "${RED} -------- download pgo profiles ${NC}"
cd $WORKSPACE/chromium/src
if has_target android; then
  # android-arm64 public profiles are gone; desktop profiles are the substitute
  python3 tools/update_pgo_profiles.py --target=android-desktop-arm64 update --gs-url-base=chromium-optimization-profiles/pgo_profiles
  python3 tools/update_pgo_profiles.py --target=android-desktop-x64 update --gs-url-base=chromium-optimization-profiles/pgo_profiles
  python3 tools/update_pgo_profiles.py --target=android-arm32 update --gs-url-base=chromium-optimization-profiles/pgo_profiles
fi
if has_target linux; then
  python3 tools/update_pgo_profiles.py --target=linux update --gs-url-base=chromium-optimization-profiles/pgo_profiles
fi
python3 v8/tools/builtins-pgo/download_profiles.py download --depot-tools third_party/depot_tools --check-v8-revision
python3 tools/download_optimization_profile.py --newest_state=chrome/android/profiles/newest.txt \
  --local_state=chrome/android/profiles/local.txt \
  --output_name=chrome/android/profiles/afdo.prof \
  --gs_url_base=chromeos-prebuilt/afdo-job/llvm
python3 tools/download_optimization_profile.py --newest_state=chrome/android/profiles/arm.newest.txt \
  --local_state=chrome/android/profiles/arm.local.txt \
  --output_name=chrome/android/profiles/arm.afdo.prof \
  --gs_url_base=chromeos-prebuilt/afdo-job/llvm

echo -e "${RED} -------- build modified ninja ${NC}"
cd $WORKSPACE/
git clone https://github.com/ninja-build/ninja.git -b v1.8.2
cd ninja
git apply $REPO_DIR/tools/ninja-one-target-for-compdb.patch
CXX=clang++ ./configure.py --bootstrap
mv $WORKSPACE/ninja/ninja $WORKSPACE/ninja/ninja-modified || true

echo -e "${RED} -------- download clang prebuilds ${NC}"
cd $WORKSPACE/chromium/src
python3 tools/clang/scripts/update.py --package=clang --host-os=linux --no-clear=true
if has_target win; then
  python3 tools/clang/scripts/update.py --package=clang --host-os=win --no-clear=true
  python3 third_party/depot_tools/download_from_google_storage.py \
      --no_resume \
      --bucket chromium-browser-clang/rc \
      -s build/toolchain/win/rc/linux64/rc.sha1
fi

echo -e "${RED} -------- bootstrap python3 for gn ${NC}"
cd $WORKSPACE/chromium/src
echo ../../../../../usr/bin >$WORKSPACE/depot_tools/python3_bin_reldir.txt
