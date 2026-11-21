#!/usr/bin/env bash
# Blazing (claude-ps3-recomp-1, 21 Nov 2026): build lavavex/rpcs3-PS5 on the Dell WSL "Blazing" distro (Ubuntu 24.04)
# in /root/ps3-recomp. Run held over ssh:  ssh dell 'wsl -d Blazing -u root -- bash /root/ps3-recomp/bootstrap.sh'
# Fixes for Ubuntu vs lavavex's Arch host:
#  1. ps5-opengl SDK 0.3.0 release tarball is 404 (blackbearreloaded/ps5-opengl deleted) -> J7mbo/ps5-opengl 8f927859
#     (1.0.2 source, the pin Michele-M-Media's recompiler uses) as deps/ps5-opengl-sdk-0.3.0.
#  2. Mesa clc host tools: apt has LLVMSPIRVLib 18 only -> configure radv-clc-build with llvm-config-18
#     (on a fresh tree the first run stops at that step because radv-src does not exist yet: run it again).
#  3. rpcs3 submodule -> Kaoz625/rpcs3 blz/dante-tile (per-tile /app0/boot.txt, BLZ_FPS log, RADV cache dir).
set -uo pipefail
mkdir -p /root/ps3-recomp/shim /root/build-locks
exec > >(tee -a /root/ps3-recomp/bootstrap.log) 2>&1
echo "=== start $(date)"
export DEBIAN_FRONTEND=noninteractive
dpkg -s nasm python3-ply spirv-headers llvm-spirv-18 >/dev/null 2>&1 || apt-get install -y -q nasm python3-ply spirv-headers llvm-spirv-18
ln -sf /usr/bin/clang-21 /root/ps3-recomp/shim/clang
ln -sf /usr/bin/clang++-21 /root/ps3-recomp/shim/clang++
ln -sf /usr/bin/llvm-spirv-18 /root/ps3-recomp/shim/llvm-spirv
export PATH=/root/ps3-recomp/shim:$PATH
cd /root/ps3-recomp
[ -d rpcs3-PS5 ] || git clone -q https://github.com/lavavex/rpcs3-PS5
cd rpcs3-PS5
bash tools/fetch-deps.sh
deps=$PWD/deps; src=$deps/ps5-opengl-src/ps5-opengl
if [[ ! -d $src/.git ]]; then
  mkdir -p $deps/ps5-opengl-src; git clone -q https://github.com/J7mbo/ps5-opengl $src
  git -C $src checkout -q 8f927859fcca5ce3190a8dde6863a07489b18a74
fi
[[ -e $deps/ps5-opengl-sdk-0.3.0 ]] || ln -s $src $deps/ps5-opengl-sdk-0.3.0
[[ -d $src/third_party/opengnm-psbc ]] || (cd $src && python3 tools/fetch-sources.py)
# Blazing rpcs3 patch
r=src/rpcs3
if ! git -C $r log --oneline -1 | grep -q 'per-tile /app0/boot.txt'; then
  git -C $r fetch -q https://github.com/Kaoz625/rpcs3 blz/dante-tile && git -C $r checkout -q FETCH_HEAD
fi
echo "claude-ps3-recomp-1: rpcs3-PS5 bootstrap $(date)" > /root/build-locks/ps3-recomp.lock
bash tools/install-sdk.sh
vk=$deps/PS5_Vulkan; clc=$vk/.deps/work/radv-clc-build
if [[ ! -f $clc/build.ninja && -d $vk/.deps/work/radv-src ]]; then
  printf "[binaries]\nllvm-config = '/usr/bin/llvm-config-18'\n" > $vk/.deps/work/clc-native.ini
  meson setup $clc $vk/.deps/work/radv-src --native-file $vk/.deps/work/clc-native.ini -Dbuildtype=release \
    -Dmesa-clc=enabled -Dinstall-mesa-clc=true -Dgallium-drivers= -Dvulkan-drivers= -Dplatforms= -Dglx=disabled \
    -Degl=disabled -Dgbm=disabled -Dopengl=false -Dgles1=disabled -Dgles2=disabled -Dllvm=enabled -Dshared-llvm=enabled \
    -Dbuild-tests=false -Dvalgrind=disabled -Dlibunwind=disabled -Dzstd=disabled -Dxmlconfig=disabled -Dtools= >/dev/null
fi
time bash tools/bootstrap.sh
rc=$?
echo "=== end rc=$rc $(date)"
rm -f /root/build-locks/ps3-recomp.lock
exit $rc
