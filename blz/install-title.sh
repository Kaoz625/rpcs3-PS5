#!/usr/bin/env bash
# Blazing: install a per-game RPCS3 tile on a PS5 M.2 (default: Dante's Inferno, PPSA99345 on PHAT5).
#   blz/install-title.sh [CONSOLE] [TID]       run on the MacBook (blazing-ps5 repo at ~/NYCT/blazing-ps5)
# 1. pulls dist/PPSA99300 (eboot.bin, sce_module, Icons, ...) from the Dell build
# 2. replaces sce_sys with blz/<TID>/sce_sys (param.json = official name, icon0 = real art; pic0/pic1 made by
#    blazing-ps5 tools/tile-art.py from the disc's PIC1.PNG) and adds blz/<TID>/boot.txt (the game this tile boots)
# 3. uploads to /mnt/ext1/homebrew/<TID> with put-tree (sha256 read-back): everything but sce_sys FIRST, sce_sys last
#    (ShadowMount gives up if it sees sce_sys before eboot.bin), then register-game.py --check.
# The game's disc folder goes in <TID>/game/<PS3 ID>/ (separately), RPCS3's data (firmware, dev_hdd0 = Update + DLC,
# saves, caches) in /data/rpcs3 (shared by every RPCS3 tile).
set -euo pipefail
console=${1:-PHAT5}; tid=${2:-PPSA99345}
here=$(cd -- "$(dirname -- "$0")" && pwd)
work=${BLZ_WORK:-$(mktemp -d)}/$tid
ps5=${BLZ_PS5_REPO:-$HOME/NYCT/blazing-ps5}
rm -rf "$work"; mkdir -p "$work"
ssh dell 'wsl -d Blazing -u root -- tar -C /root/ps3-recomp/rpcs3-PS5/dist/PPSA99300 -cf - .' | tar -C "$work" -xf -
rm -rf "$work/sce_sys.dist"; mv "$work/sce_sys" "$work/sce_sys.dist"
mkdir -p "$work/../$tid-sys/sce_sys"
cp "$work/sce_sys.dist/"* "$work/../$tid-sys/sce_sys/" 2>/dev/null || true
rm -rf "$work/sce_sys.dist"
cp "$here/$tid/sce_sys/"* "$work/../$tid-sys/sce_sys/"
[[ -f ${BLZ_PIC0:-} ]] && cp "$BLZ_PIC0" "$work/../$tid-sys/sce_sys/pic0.dds" && cp "$BLZ_PIC0" "$work/../$tid-sys/sce_sys/pic1.dds"
cp "$here/$tid/boot.txt" "$work/boot.txt"
python3 "$ps5/tools/put-tree.py" "$console" "$work" "/mnt/ext1/homebrew/$tid" --jobs 4 --tid "$tid"
python3 "$ps5/tools/put-tree.py" "$console" "$work/../$tid-sys" "/mnt/ext1/homebrew/$tid" --jobs 2 --tid "$tid"
python3 "$ps5/tools/register-game.py" "$console" "/mnt/ext1/homebrew/$tid" --check || true
echo "installed $tid on $console"
