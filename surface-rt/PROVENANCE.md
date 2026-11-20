# linux-surface-rt: where each part comes from

Every patch here is one of the following:

- **mainline**: from the Linux kernel, a kernel.org release, cited;
- **public tree**: from another public, licensed source tree, cited with its commit or tag; the
  original author, date, message and sign-offs are kept, and a last paragraph names the tree;
- **our own**: written for this kernel from the mainline sources and public documentation, the
  hardware description the firmware's ACPI tables give as published on the Open Surface RT wiki, what
  a unit's own running Linux shows (its registers, its `/proc` and `/sys` files, its logs), black-box
  tests on a unit, or measurements on a unit.

Anything derived from a vendor's unpublished or proprietary sources is not in this repository.

## Inputs

| Input | Source |
| --- | --- |
| Linux 7.3.5 | kernel.org, `linux-7.3.5.tar.xz`, sha256 `8f293f83d54f0b7b9be56863ebc5e4ea79d73e530b4ae55c572be97ef39f0990` |
| libre-tegra | codeberg.org/libre-tegra/linux, tag `v7.0.1-stable`, commit `bfffc6d6656e` (the kernel postmarketOS packages as `linux-postmarketos-grate`), GPL-2.0 |
| nerves_system_surface_rt | github.com/CoderDennis/nerves_system_surface_rt, branch `main`, commit `d068902a00ff`, `linux/` (GPL-2.0-only), by Dennis Palmer |
| NVIDIA's Tegra Android kernel | android.googlesource.com/kernel/tegra, commit `2268683075e741190919217a72fcf13eb174dc57`, GPL-2.0 |
| The Surface RT's ACPI tables | Open Surface RT wiki, open-rt.gitbook.io/open-surfacert/surface-rt/uefi/acpi-tables/acpi-ssdt (the decompiled `SSDT0000.ASL` attached there), sha256 of that file `1005e987763e7ff644b8be6fcb01488c484542092363aed8e09e4fce644059ab` |

## patches/

| Patch | What | Category | Reference |
| --- | --- | --- | --- |
| `0001-ARM-kernel-Add-ACPI-Parking-Protocol-for-ARM32-devic.patch` | secondary CPUs through the ACPI parking protocol (Glanda) | public tree | libre-tegra `49bd9aab5342`, `arch/arm/kernel/acpi_parking_protocol.c`, `arch/arm/include/asm/acpi_parking_protocol.h`, `arch/arm/kernel/setup.c`; byte-identical to v7.0.1-stable |
| `0002-firmware-tf-add-surface-rt-support.patch` | L2C-310 control through the secure monitor's Trusted Foundations calls (Pohrom) | public tree | libre-tegra `db47272937b0` and `2017767150cd`: `drivers/firmware/trusted_foundations.c`, `include/linux/firmware/trusted_foundations.h`, `arch/arm/mm/cache-l2x0.c`, `arch/arm/include/asm/outercache.h`; byte-identical |
| `0003-i2c-Add-GPIO-based-hotplug-gate.patch` | GPIO hotplug gate for the cover's I2C bus (Michał Mirosław, Ion Agorria), the cover's address 0x00 (Anton Bambura) | public tree | libre-tegra `0458cc7f344e` (`drivers/i2c/i2c-hotplug-gpio.c`, Kconfig, Makefile) and `f8a8101e8e51` (`drivers/i2c/i2c-core-base.c`); byte-identical |
| `0004-HID-microsoft-add-quirk-to-tCover-2nd-gen.patch` | Type/Touch Cover 2 quirk (Jonas Schwöbel) | public tree | libre-tegra `4ecd00c69279`, `drivers/hid/hid-microsoft.c`; byte-identical |
| `0005-mfd-tps65910-Use-devm_register_power_off_handler.patch` | TPS65910 power-off handler and restart handler (Dmitry Osipenko) | public tree | libre-tegra `262eeef27afa` and `b4f940c8ba4d`, `drivers/mfd/tps65910.c`; the same handlers, on 7.2's version of the file |
| `0006-ARM-tegra-Add-device-tree-for-Microsoft-Surface-RT.patch` | the Surface RT device trees, `tegra30-microsoft-surface-rt.dts` and `-efi.dts` (Jonas Schwöbel, Anton Bambura) | public tree | libre-tegra `ed18878a590a`; byte-identical to v7.0.1-stable |
| `0007-memory-tegra-Don-t-error-out-DMA-flushing.patch` | a DMA flush timeout no longer fails the memory controller's hot reset (Dmitry Osipenko) | public tree | libre-tegra `8d0f5f4f9fff`, `drivers/memory/tegra/mc.c`; the same code, plus our comment on the Surface RT case (the 3D2 client never drains; seen on a unit) |
| `0008-ARM-dts-tegra30-surface-rt-wire-up-the-internal-digi.patch` | the WM8962's digital microphones | our own | black-box: GPIO pin pairs tried on a unit |
| `0009-watchdog-Add-TPS65911-watchdog-driver.patch` | TPS65911 watchdog driver (Dennis Palmer) | public tree | nerves_system_surface_rt, `linux/0014-watchdog-Add-TPS65911-watchdog-driver.patch`; same code and message |
| `0010-ASoC-wm8962-Don-t-turn-off-SYSCLK-that-was-already-o.patch` | WM8962: keep SYSCLK on when it was already on (Dennis Palmer) | public tree | nerves_system_surface_rt, `linux/0013-ASoC-wm8962-Don-t-turn-off-SYSCLK-that-was-already-o.patch`; 7.2's `snd_soc_dapm_get_bias_level()` |
| `0011-ARM-dts-tegra30-surface-rt-the-DMIC-data-line-is-on-.patch` | the microphones' data line is on GPIO5 | our own | black-box: a speaker-to-microphone loopback test |
| `0012-regulator-tps65910-don-t-clear-external-sleep-contro.patch`, `0013-regulator-tps65910-don-t-clear-external-sleep-contro.patch` | TPS65910: no external sleep control clearing on restart and power-off | our own | mainline tps65910-regulator; the hang found by logging the device shutdown on a unit |
| `0014-usb-chipidea-Don-t-bounce-URBs-with-their-own-DMA-ma.patch` | ChipIdea: no bounce buffer for URBs with their own DMA mapping (Dennis Palmer) | public tree | nerves_system_surface_rt, `linux/0007-usb-chipidea-Don-t-bounce-URBs-with-their-own-DMA-mapping.patch`; same code and message |
| `0015-cpuidle-tegra-keep-only-WFI-when-the-secure-monitor-.patch` | cpuidle-tegra: only WFI when the secure monitor cannot set the resume address | our own | mainline cpuidle-tegra and the Trusted Foundations ops of `0002-firmware-tf-add-surface-rt-support.patch`; the hang in C7/CC6 from tests on a unit |
| `0016-ARM-dts-tegra30-surface-rt-drop-the-SPI-NOR-boot-fla.patch` | no SPI NOR boot flash | our own | device-observed: the JEDEC ID reads all zeros |
| `0017-media-tegra-vde-use-a-semaphore-for-the-hardware-loc.patch` | tegra-vde: a semaphore for the hardware lock | our own | mainline tegra-vde; the lockdep warning in a unit's log |
| `0018-media-tegra-vde-allocate-bitstream-buffers-write-com.patch` | tegra-vde: write-combined bitstream buffers | our own | mainline vb2-dma-contig; measured on a unit (GStreamer, 300 frames, bit-exact output) |
| `0019-ARM-dts-tegra30-surface-rt-route-the-headphone-outpu.patch` | headphones on the jack-switched DAPM pin | our own | mainline tegra_wm8962 machine driver |
| `0020-ARM-tegra-surface-rt-Describe-the-UART-Bluetooth-wir.patch` | Bluetooth's UART wiring, PD1 hog | our own | the firmware's ACPI tables, `\_SB.BTH0` (`NVDAF000`: 115200 baud, hardware flow control, interrupt 0xa6 = PU6, output 0x19 = PD1), Open Surface RT wiki, open-rt.gitbook.io/open-surfacert/surface-rt/uefi/acpi-tables/acpi-ssdt (the decompiled `SSDT0000.ASL` attached there); that it runs on UARTC and that PD1 is high as the boot firmware leaves it, from tests on a unit |
| `0021-dt-bindings-media-i2c-add-OmniVision-OV9726.patch` | OV9726 binding | our own | the mainline video-interfaces bindings |
| `0022-media-i2c-add-OmniVision-OV9726-sensor-driver.patch` | OV9726 sensor driver | public tree, and our own | the register tables of NVIDIA's `drivers/media/platform/tegra/ov9726.c` (Copyright (c) 2011 - 2013, NVIDIA, GPL-2.0) in NVIDIA's Tegra Android kernel at the commit above, with the output height set to 720 lines (0x034e/0x034f = 0x02d0 for 0x02d8); the rest our own, on the mainline V4L2 and CCI APIs |
| `0023-ARM-tegra-surface-rt-describe-the-cameras.patch` | the cameras: VI/CSI and the two sensors | our own | the power sequence of the firmware's ACPI `\_SB.GFXC.CAM1.CPWR` (1.8 V enable BB4, LDOs R6/R7, resets BB0/BB7), Open Surface RT wiki, open-rt.gitbook.io/open-surfacert/surface-rt/uefi/acpi-tables/acpi-ssdt (the decompiled `SSDT0000.ASL` attached there); the CSI lanes and capture from tests on a unit |
| `0024-drm-tegra-gem-skip-CPU-cache-maintenance-when-pinnin.patch` | tegra GEM: no CPU cache maintenance when pinning native BOs | our own | mainline drm/tegra; measured on a unit (perf) |
| `0025-wifi-mwifiex-use-the-legacy-scan-with-pre-14.68-firm.patch` | mwifiex: legacy scan with firmware older than 14.68 | our own | mainline mwifiex; the extended scan's result 2 from tests on a unit |
| `0026-media-i2c-ov9726-fix-Bayer-order-and-gain-drop-test-.patch` | OV9726: Bayer order, gain, no test pattern | our own | black-box: captures on a unit |
| `0027-staging-media-tegra-video-tegra20-fix-slow-frame-rat.patch` | tegra-video (Tegra20/30): slow frame rates, no fence leak | our own | mainline tegra-video and host1x; tested at 30, 5 and 1 fps on a unit |
| `0028-gpu-host1x-cancel-the-fence-when-an-interruptible-wa.patch` | host1x: cancel the fence of an interrupted wait | our own | mainline host1x |
| `0029-media-i2c-ov9726-honour-DT-rotation-drop-the-vertica.patch` | OV9726: DT rotation, no vertical flip control | our own | the CSI pixel parser's status read on a unit |
| `0030-staging-media-tegra-video-VI-vflip-for-upside-down-s.patch` | tegra-video: VI vertical flip | our own | mainline tegra-video; tested on a unit |
| `0031-ARM-tegra-surface-rt-cameras-are-mounted-upside-down.patch`, `0032-ARM-tegra-surface-rt-front-camera-is-CAM1-on-CSI-A.patch`, `0033-ARM-tegra-surface-rt-the-front-camera-CAM1-is-mounte.patch` | which camera is front and rear, and their mounting | our own | black-box: captures on a unit |
| `0034-ARM-dts-tegra30-say-512-byte-blocks-in-the-SDHCI-cap.patch` | Tegra30 SDHCI: 512-byte blocks in the capabilities | our own | the SDHCI specification; the warning in a unit's log |
| `0035-ARM-dts-tegra30-surface-rt-describe-the-HDMI-LVDS-to.patch` | supplies of HDMI, the LVDS encoder, the touchscreen and the NCT1008 | our own | mainline's TPS65911 Tegra30 boards (Cardhu, the Transformers); the firmware's ACPI tables give `\_SB.GFXC.HDMI` no power resource and `\_SB.PRTU`'s `_ON`/`_OFF` only set a flag, Open Surface RT wiki, open-rt.gitbook.io/open-surfacert/surface-rt/uefi/acpi-tables/acpi-ssdt (the decompiled `SSDT0000.ASL` attached there) |
| `0036-ARM-dts-tegra30-surface-rt-no-L2C-310-full-line-of-z.patch` | no L2C-310 full line of zeros | our own | the Cortex-A9 TRM (ACTLR, NSACR); the warning in a unit's log |
| `0037-ARM-dts-tegra30-surface-rt-dimmer-backlight-floor-pe.patch`, `0044-ARM-tegra-surface-rt-linear-backlight-levels-at-1-kH.patch` | the backlight PWM at 1 kHz, linear levels | our own | the Tegra PWM's 8-bit duty; black-box on a unit |
| `0038-driver-core-fw_devlink-a-probed-consumer-needs-no-sy.patch` | fw_devlink: no sync-state link for a probed consumer | our own | mainline driver core; the error in a unit's log |
| `0039-clk-tegra30-drop-the-cclk-lookups-whose-names-do-not.patch` | clk-tegra30: drop clkdev lookups with names over 16 characters | our own | mainline clkdev |
| `0040-gpio-tegra-allocate-the-GPIO-base-dynamically.patch` | gpio-tegra: dynamic GPIO base | our own | mainline gpiolib |
| `0041-ASoC-tegra30-ahub-read-uncached-registers-from-the-h.patch`, `0043-ASoC-tegra30-i2s-read-uncached-registers-from-the-ha.patch` | tegra30 AHUB and I2S: sparse flat register cache | our own | mainline regmap (`REGCACHE_FLAT_S`) |
| `0042-ASoC-wm8962-resume-the-codec-to-set-up-microphone-de.patch` | WM8962: runtime-resume for microphone detection | our own | mainline wm8962; the error in a unit's log |
| `0045-soc-tegra-pmc-mark-the-early-instance-synced-too.patch` | tegra-pmc: mark the early instance synced too | our own | mainline `drivers/soc/tegra/pmc.c`; the CORE voltage read on a unit |
