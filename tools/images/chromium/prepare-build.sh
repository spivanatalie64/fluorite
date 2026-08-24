#!/bin/bash
# Fetches a clean Chromium checkout at $VERSION into /workspace/chromium/src.
# Generic: target platforms configurable via TARGET_OS_LIST.
set -e

RED='\033[0;31m'
NC='\033[0m'

WORKSPACE=${WORKSPACE:-/workspace}
TARGET_OS_LIST=${TARGET_OS_LIST:-"android"}

echo -e "${RED} -------- chromium version is: $VERSION ${NC}"

echo -e "${RED} -------- cloning depot_tools ${NC}"
cd $WORKSPACE
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git

export PATH=$WORKSPACE/depot_tools:$PATH
export DEPOT_TOOLS_UPDATE=0

echo -e "${RED} -------- download chromium repo ${NC}"
mkdir ./chromium
cd ./chromium
gclient root
mkdir ./src
cd ./src

CHR_SOURCE=https://chromium.googlesource.com/chromium/src.git
git init
git remote add origin $CHR_SOURCE

git fetch --depth 2 $CHR_SOURCE +refs/tags/$VERSION:chromium_$VERSION
git checkout $VERSION
VERSION_SHA=$( git show-ref -s $VERSION | head -n1 )

OS_ARRAY=$( for os in $TARGET_OS_LIST; do printf "'%s'," "$os"; done | sed 's/,$//' )

cat > ../.gclient <<EOF
solutions = [
  { "name"        : 'src',
    "url"         : '$CHR_SOURCE@$VERSION_SHA',
    "deps_file"   : 'DEPS',
    "managed"     : False,
    "custom_deps" : {
        "src/third_party/apache-windows-arm64": None,
        "src/third_party/updater/chrome_win_x86": None,
        "src/third_party/updater/chrome_win_x86_64": None,
        "src/third_party/updater/chromium_win_x86": None,
        "src/third_party/updater/chromium_win_x86_64": None,
        "src/third_party/gperf": None,
        "src/third_party/lighttpd": None,
        "src/third_party/lzma_sdk/bin/host_platform": None,
        "src/third_party/perl": None,
        "src/tools/skia_goldctl/win": None,
        "src/third_party/screen-ai/windows_amd64": None,
        "src/third_party/cronet_android_mainline_clang/linux-amd64": None,
        "src/testing/libfuzzer/fuzzers/wasm_corpus": None,
    },
    "custom_hooks" : [
        { 'name': 'ciopfs_linux', 'pattern': '.', 'action': ['echo', 'ciopfs_linux hook override'] },
        { 'name': 'win_toolchain', 'pattern': '.', 'action': ['echo', 'win_toolchain hook override'] },
        { 'name': 'rc_win', 'pattern': '.', 'action': ['echo', 'rc_win hook override'] },
        { 'name': 'rc_linux', 'pattern': '.', 'action': ['echo', 'rc_linux hook override'] },
        { 'name': 'apache_win32', 'pattern': '.', 'action': ['echo', 'apache_win32 hook override'] },
    ],
    "custom_vars": {
       "checkout_android_prebuilts_build_tools": True,
       "checkout_telemetry_dependencies": False,
       "codesearch": 'Debug',
    },
  },
]
target_os=[$OS_ARRAY]
EOF

cat ../.gclient

git submodule foreach git config -f ./.git/config submodule.$name.ignore all
git config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'

echo -e "${RED} -------- sync third_party repos ${NC}"
gclient sync -D --no-history --nohooks

git config user.email "build@example.com"
git config user.name "Builder"

echo -e "${RED} -------- running hooks ${NC}"
gclient runhooks

echo -e "${RED} -------- download objdump ${NC}"
tools/clang/scripts/update.py --package=objdump

echo -e "${RED} -------- remove non-useful big stuffs ${NC}"
rm -rf third_party/angle/third_party/VK-GL-CTS/
