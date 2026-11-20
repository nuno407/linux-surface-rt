#!/bin/bash
# SPDX-License-Identifier: MIT
#
# surface-rt/build.sh: build Linux 7.3.5 for the Microsoft Surface RT (Tegra 3, Tegra30): the kernel,
# its device trees and the modules. It runs inside the build container; ../build.sh starts it there.
# See README.md.
#
# Environment:
#   WORK       work directory: the kernel tree and its objects (default /src/surface-rt)
#   CACHE      where downloads are kept (default $WORK/cache)
#   OUT        output directory for the artifacts (default $WORK/out)
#   KTREE      use this unpacked linux-7.3.5 tree in place instead of a fresh one
#   JOBS       parallel make jobs (default: nproc)
#   OVERLAY    a directory with surface-rt/overlay.sh, which may add patches, configuration and steps
#              (see README.md, "Overlays")
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
PUB=$HERE
WORK=${WORK:-/src/surface-rt}
JOBS=${JOBS:-$(nproc)}

KVER=7.3.5
KURL=https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-$KVER.tar.xz
KSHA256=8f293f83d54f0b7b9be56863ebc5e4ea79d73e530b4ae55c572be97ef39f0990

# What an overlay may change. The build's identity is fixed, so a build is reproducible; it is what
# `uname -v` says, so move the timestamp on whenever the kernel changes.
SERIES=$HERE/series
CONFIG=$HERE/config/surface-rt.config
# Modules are not signed here: a signing key made at build time would change the kernel's bytes on
# every build. An overlay that signs them brings its own key (config_hook).
CONFIG_FRAGMENTS=("$HERE/config/unsigned.config")
# The device trees, from the tree's arch/arm/boot/dts/nvidia: the plain one, and the one for booting
# through the UEFI firmware.
DTBS=(tegra30-microsoft-surface-rt tegra30-microsoft-surface-rt-efi)
LOCALVERSION=${LOCALVERSION:--surface}
# Appended to the release string by make, after LOCALVERSION (an overlay's own marker).
LOCALVERSION_MAKE=${LOCALVERSION_MAKE:-}
KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-builder}
KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-surface-rt-build}
KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-2026-11-02 00:00:00 UTC}
KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION:-1}
# Called with the object directory once the configuration is final, before the build.
config_hook() { :; }
if [ -n "${OVERLAY:-}" ]; then
	OVL=$(cd "$OVERLAY" && pwd)
	# shellcheck source=/dev/null
	. "$OVL/surface-rt/overlay.sh"
fi

export ARCH=arm CROSS_COMPILE=${CROSS_COMPILE-arm-linux-gnueabihf-}
export KBUILD_BUILD_USER KBUILD_BUILD_HOST KBUILD_BUILD_TIMESTAMP KBUILD_BUILD_VERSION
export LC_ALL=C

CACHE=${CACHE:-$WORK/cache}
OUT=${OUT:-$WORK/out}
mkdir -p "$WORK" "$CACHE" "$OUT"
WORK=$(cd "$WORK" && pwd) OUT=$(cd "$OUT" && pwd) CACHE=$(cd "$CACHE" && pwd)

fetch() { # fetch URL DEST SHA256
	if [ ! -f "$2" ] || ! echo "$3  $2" | sha256sum -c --quiet - 2>/dev/null; then
		mkdir -p "$(dirname "$2")"
		curl -sSfL -o "$2.part" "$1"
		mv "$2.part" "$2"
	fi
	echo "$3  $2" | sha256sum -c --quiet - || { echo "sha256 mismatch: $2" >&2; exit 1; }
}

# apply PATCH: apply a patch to the tree once. A tree it was applied to (a marker in .applied/, as later
# steps may change the same files) or that already has it is left alone.
apply() {
	local mark
	mark=$KTREE/.applied/$(basename "$1").$(sha256sum < "$1" | cut -c1-16)
	[ -e "$mark" ] && return 0
	if (cd "$KTREE" && git apply --check "$1" 2>/dev/null); then
		(cd "$KTREE" && git apply "$1")
	elif ! (cd "$KTREE" && git apply --reverse --check "$1" 2>/dev/null); then
		echo "the kernel source does not match $1" >&2
		return 1
	fi
	mkdir -p "$KTREE/.applied" && touch "$mark"
}

# 1. Kernel source
if [ -n "${KTREE:-}" ]; then
	KTREE=$(cd "$KTREE" && pwd)
	grep -q "^SUBLEVEL = ${KVER##*.}$" "$KTREE/Makefile" || { echo "$KTREE is not linux-$KVER" >&2; exit 1; }
else
	fetch "$KURL" "$CACHE/linux-$KVER.tar.xz" "$KSHA256"
	KTREE=$WORK/linux-$KVER
	rm -rf "$KTREE"
	tar -C "$WORK" -xJf "$CACHE/linux-$KVER.tar.xz"
fi

# 2. Patches, one step a line of the series, in order.
OVL=${OVL:-}
KDIR=$KTREE
export PUB OVL KTREE KDIR WORK
export -f apply
while IFS= read -r step; do
	case $step in ''|'#'*) continue;; esac
	(cd "$WORK" && eval "$step") || { echo "series step failed: $step" >&2; exit 1; }
done < "$SERIES"

# 3. Configuration. The objects go to out/ in the tree, made anew with the tree (KTREE reuses both).
cd "$KTREE"
O=$KTREE/out
mkdir -p "$O"
cp "$CONFIG" "$O/.config"
for frag in "${CONFIG_FRAGMENTS[@]}"; do
	cat "$frag" >> "$O/.config"
done
scripts/config --file "$O/.config" --set-str LOCALVERSION "$LOCALVERSION"
make -s O="$O" olddefconfig
grep -qxF "CONFIG_LOCALVERSION=\"$LOCALVERSION\"" "$O/.config" || { echo "config check failed: LOCALVERSION" >&2; exit 1; }
config_hook "$O"

# 4. Build
make -s O="$O" -j"$JOBS" LOCALVERSION="$LOCALVERSION_MAKE" zImage dtbs modules
release=$(make -s O="$O" LOCALVERSION="$LOCALVERSION_MAKE" kernelrelease)
cp "$O/arch/arm/boot/zImage" "$OUT/zImage"
files=(zImage)
for dtb in "${DTBS[@]}"; do
	cp "$O/arch/arm/boot/dts/nvidia/$dtb.dtb" "$OUT/"
	files+=("$dtb.dtb")
done
cp "$O/.config" "$OUT/kernel.config"
echo "$release" > "$OUT/kernel.release"

# 5. Modules, as lib/modules/<release> under the root of a tarball, without their debug information
# (signed after stripping, when an overlay signs them)
R=$WORK/modules-root
rm -rf "$R"
make -s O="$O" LOCALVERSION="$LOCALVERSION_MAKE" INSTALL_MOD_PATH="$R" INSTALL_MOD_STRIP=1 modules_install
rm -f "$R/lib/modules/$release/build" "$R/lib/modules/$release/source"
tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner -C "$R" -cf - . | gzip -9n > "$OUT/modules.tar.gz"
files+=(modules.tar.gz kernel.config kernel.release)

cd "$OUT"
sha256sum "${files[@]}" > SHA256SUMS
python3 "$HERE/../common/manifest.py" surface-rt "$KVER" "$KSHA256" . "${files[@]}"
cat SHA256SUMS
