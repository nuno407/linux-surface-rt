# linux-surface-rt

Build scripts and patches that turn a kernel.org Linux release into a kernel for the Microsoft
Surface RT (2012), a tablet with an NVIDIA Tegra 3 (Tegra30) system on a chip.

The build makes Linux 7.3.5 from the kernel.org tarball, checked against its sha256, and produces
versioned *artifacts*: the compressed kernel `zImage`, the device trees, the modules and a
`manifest.json` that lists them with their sizes and sha256 sums. How they are booted (the UEFI
firmware, a boot loader, a root filesystem) is up to the system built on top.

This project is not affiliated with, endorsed by or sponsored by Microsoft or NVIDIA. Microsoft and
Surface are trademarks of Microsoft Corporation. NVIDIA and Tegra are trademarks of NVIDIA
Corporation.

## What you need

- A Surface RT whose firmware starts a Linux kernel you built. A stock unit does not: it only starts
  what Microsoft signed. How to get there is not covered here.
- Docker. The build runs in a Debian 13 container for the host's own architecture
  (`docker/Dockerfile`) with the cross compiler for 32-bit ARM; nothing is emulated.
- About 4 GB of disk for the kernel tree and its objects, kept in a Docker volume, not on the host.
- A network connection the first time, for the kernel tarball (about 160 MB). Every other source is in
  this repository ([SOURCES.md](SOURCES.md)).

## Building

    ./build.sh surface-rt          # artifacts in out/surface-rt

The first run builds the container image (`linux-surface-rt-build`) and creates the volume
(`linux-surface-rt-src`). A build takes about 30 minutes on a 4-core desktop. Each run starts from a
fresh kernel tree; `KTREE=/src/surface-rt/linux-7.3.5` reuses the tree of the run before, which only
rebuilds what changed.

Settings, as environment variables: `BUILD_IMAGE` and `VOLUME` choose another container image or
volume, `WORK` the work directory in the volume, `CACHE` where downloads are kept and `JOBS` the
number of parallel jobs.

## Artifacts

`zImage`, `tegra30-microsoft-surface-rt.dtb`, `tegra30-microsoft-surface-rt-efi.dtb` (for booting
through the UEFI firmware), `modules.tar.gz` (`lib/modules/<release>`, stripped), `kernel.config` and
`kernel.release`, with `SHA256SUMS` and `manifest.json`. The manifest names the device, the Linux
version and its tarball's sha256, the kernel release string, the commit of this repository the build
came from, and every file with its size and sha256. A system built on these kernels can pin a kernel
by those sums.

A build is reproducible: the build stamp (`uname -v`) is fixed in `surface-rt/build.sh`, the modules
are not signed (a key made at build time would change the kernel's bytes; the lockdown LSM, which
selects signing, is left out with it, `config/unsigned.config`), and the same commit built in the same
container image gives the same bytes. An overlay that signs brings its own key and puts both back. The GNU build IDs of the kernel and its vDSO also
hash the build directory's path, so they match only for the same `WORK`.

## How it is built

`surface-rt/` has:

- `build.sh`: fetches the kernel, applies the series, configures and builds the kernel, and writes the
  artifacts. It runs inside the container.
- `series`: the patch steps, one shell command a line, in order, grouped by where they come from.
- `patches/`: the patches, in `git format-patch` form, each with its original author.
- `config/`: the whole configuration (`surface-rt.config`) and the fragments added to it.
- `PROVENANCE.md`: where each patch comes from: mainline or another public tree (cited by repository,
  commit and file), the firmware's ACPI tables as the Open Surface RT wiki publishes them, facts read
  from the tablet's own running Linux, black-box tests, or our own work on mainline drivers.

## Overlays

An *overlay* is a directory that adds to a build without changing this repository: more patches, more
configuration, steps of its own and its own build identity. Set `OVERLAY` to it:

    OVERLAY=/path/to/overlay ./build.sh surface-rt

`surface-rt/build.sh` then sources `<overlay>/surface-rt/overlay.sh`, which may set:

| Variable or function | Meaning |
| --- | --- |
| `SERIES` | a series file to use instead of this one; it can run this repository's steps (`$PUB/...`) and the overlay's (`$OVL/...`) in any order |
| `CONFIG_FRAGMENTS` | more configuration lines, appended to the configuration before `olddefconfig` |
| `LOCALVERSION`, `LOCALVERSION_MAKE` | the configuration's release suffix, and one make appends after it |
| `KBUILD_BUILD_USER`, `KBUILD_BUILD_HOST`, `KBUILD_BUILD_TIMESTAMP`, `KBUILD_BUILD_VERSION` | the build stamp |
| `DTBS` | the device trees to ship, from the tree's `arch/arm/boot/dts/nvidia` |
| `config_hook` | a function run with the object directory once the configuration is final, before the build (to put a module signing key in place, for example) |

The overlay is mounted read-only at `/overlay` in the container. `PASS_ENV` names more environment
variables `build.sh` passes into the container, for the overlay's own settings.

## Licenses

The patches, the drivers and the device trees are under the licenses their files state, GPL-2.0 for
everything that goes into the kernel (see [COPYING](COPYING)); a device tree may also be MIT. The
build scripts are MIT ([LICENSE](LICENSE)).
