# IFC6410 Linux 6.6 / Yocto Kernel Release

This repository contains the reproducible Yocto BSP-layer source, configuration provenance, and release metadata for a validated **Linux 6.6** kernel build for the **Inforce IFC6410** single-board computer, based on Qualcomm's Snapdragon S4 Pro / **APQ8064** platform with Krait 300 CPUs and an Adreno 320 GPU.

The kernel is built by Yocto from `linux-linaro-qcomlt` on the Project `scarthgap` release. The included `meta-ifc6410` layer carries IFC6410-specific kernel configuration, device-tree fixes, firmware staging layout, and MSM IOMMU/DRM backports. The validated layer revision is:

```text
meta-ifc6410: b047f0ea8f89d089e675778a78ef784e73a1e115
```

> **Validated status:** The board boots to Debian multi-user mode; MSM DRM initializes; Adreno A3xx binds to MDP4; the `a300_pm4.fw` and `a300_pfp.fw` microcode files load; and Mesa 25.0.7 identifies the hardware renderer as **Freedreno FD320** through both surfaceless EGL and GBM. HDMI scanout remains a separate work item because no attached display/active connector mode has been validated.

---

## Repository Contents

```text
.
├── boot-qcom-apq8064-ifc6410--6.6-r0-qcom-armv7a-20260924162336.img
├── modules--6.6-r0-qcom-armv7a-20260924162336.tgz
├── qcom-apq8064-ifc6410.dtb
├── meta-ifc6410/
│   ├── conf/
│   │   ├── layer.conf
│   │   └── machine/qcom-armv7a.conf
│   └── recipes-kernel/linux/
│       ├── files/
│       │   ├── 0001-ARM-dma-mapping-reset-DMA-ops-before-IOMMU-detach.patch
│       │   ├── 0001-ARM-dts-ifc6410-add-audio-clock-and-regulator-nodes.patch
│       │   ├── 0001-ARM-dts-qcom-apq8064-Add-qfprom_physical-memory-reso.patch
│       │   ├── 0002-iommu-msm-track-a-context-master-per-device-and-IOMM.patch
│       │   ├── 0003-ath6kl-force-enable-ht-cap-override.patch
│       │   ├── 0003-iommu-msm-use-the-IOMMU-device-for-page-table-allocation.patch
│       │   ├── 0004-ARM-dts-qcom-ifc6410-add-Krait-CPU-clock-topology.patch
│       │   ├── 0004-drm-msm-release-ARM-DMA-mapping-before-attaching-own.patch
│       │   ├── 0005-ARM-dts-qcom-ifc6410-add-initial-CPU-OPP-table.patch
│       │   ├── 0006-ARM-dts-qcom-ifc6410-select-default-CPU-speed-bin.patch
│       │   ├── 0007-ARM-dts-qcom-ifc6410-add-CPU-thermal-cooling-maps.patch
│       │   ├── firmware/                         # local-only; ignored by Git
│       │   └── ifc6410.cfg
│       └── linux-linaro-qcomlt_%.bbappend
└── releases/
    ├── ifc6410-kernel-config-20260924-100651/
    │   ├── ifc6410-linux-6.6-effective.config
    │   ├── PROVENANCE.txt
    │   └── SHA256SUMS
    ├── ifc6410-kernel-config-20260924-100651.tar.gz.sha256
    ├── ifc6410-msm-iommu-fd320-20260924-092201/
    │   ├── kernel-patches/
    │   ├── linux-linaro-qcomlt_%.bbappend
    │   ├── meta-ifc6410.commit
    │   ├── meta-ifc6410.commit-details.txt
    │   ├── meta-ifc6410.patch
    │   ├── meta-ifc6410.status
    │   └── VALIDATION.txt
    ├── ifc6410-msm-iommu-fd320-20260924-092201.tar.gz.sha256
    ├── meta-ifc6410-b047f0e-20260924-091913.bundle
    └── meta-ifc6410-b047f0e-20260924-091913.bundle.sha256
```

The timestamped boot image, DTB, and module archive belong to the same validated build and should be used together. The dated `releases/ifc6410-kernel-config-20260924-100651/` directory is the authoritative source for the final effective kernel configuration and its provenance.

---

## Release Artifacts

| Artifact | Purpose |
|---|---|
| `boot-qcom-apq8064-ifc6410--6.6-r0-qcom-armv7a-20260924162336.img` | Fastboot-compatible IFC6410 boot image from the validated build |
| `qcom-apq8064-ifc6410.dtb` | Device tree blob matching the boot image |
| `modules--6.6-r0-qcom-armv7a-20260924162336.tgz` | Kernel modules matching the kernel build |
| `meta-ifc6410/` | Yocto BSP layer, configuration fragment, device-tree patches, and kernel backports |
| `releases/ifc6410-kernel-config-20260924-100651/` | Effective compiled `.config`, SHA-256 checksum, and build provenance |
| `releases/ifc6410-msm-iommu-fd320-20260924-092201/` | Patch, commit, and runtime-validation record for the working MSM IOMMU/Adreno path |
| `releases/meta-ifc6410-b047f0e-20260924-091913.bundle` | Portable Git bundle containing the validated `meta-ifc6410` commit |

Before flashing or sharing an artifact, verify its corresponding SHA-256 checksum from the release metadata.

---

## `meta-ifc6410` Changes

Upstream `meta-qcom` provides the generic `qcom-armv7a` baseline, but the IFC6410 needs additional board-specific work.

### CPU, regulators, and power management

- Adds APQ8064 Krait CPU clock topology, initial OPP data, and default speed-bin selection in the device tree.
- Provides regulator overrides for the PM8921/RPM setup, including explicit settings for `pm8921_s2`, `pm8921_s8`, and the `pm8921_ncp` negative charge pump.
- Enables CPUIdle/Standalone Power Collapse (`spc`) support used to power down idle Krait cores.
- The current Linux 6.6 baseline does not yet have the required APQ8064 nvmem speed-bin integration for working `qcom-cpufreq-nvmem`; the CPU therefore runs at a bootloader-selected frequency.

### Device tree and platform fixes

- Adds the missing `qfprom_physical` MMIO resource under the APQ8064 HDMI transmitter node.
- Adds board audio clock/regulator device-tree nodes.
- Configures the Yocto boot command line for a SATA/USB root filesystem at `/dev/sda1`, serial console on `ttyMSM0` at 115200 baud, cgroups v2, and conservative SATA operation with `libata.force=1.5Gbps,noncq`.

### Networking, crypto, and firmware layout

- Enables the Qualcomm hardware random-number generator (`qcom-rng`) and ARM NEON/assembly-optimized cryptography.
- Disables BMP280 sensor support because the IFC6410 PCB does not populate that sensor, avoiding irrelevant probe warnings.
- Applies the `ath6kl` high-throughput capability override for the onboard AR6004 Wi-Fi device.
- Defines the local firmware staging layout used by the kernel recipe.

### MSM IOMMU and Adreno 320

The layer includes four related ARM32 IOMMU/DRM backports:

1. `0001-ARM-dma-mapping-reset-DMA-ops-before-IOMMU-detach.patch`
2. `0002-iommu-msm-track-a-context-master-per-device-and-IOMM.patch`
3. `0003-iommu-msm-use-the-IOMMU-device-for-page-table-allocation.patch`
4. `0004-drm-msm-release-ARM-DMA-mapping-before-attaching-own.patch`

Together they handle the interaction between the legacy ARM DMA-IOMMU mapping and the DRM/MSM driver's own IOMMU domain. In particular, page tables are allocated through the MSM IOMMU device instead of through the transitioning GPU/display client device. This resolves the earlier Adreno address-space initialization stall on the IFC6410.

---

## Upstream Attribution

The MSM IOMMU and DRM-side fix direction in this layer derives from the ARM32 MSM-IOMMU patch series posted by **Dmitry Baryshkov**, with review and discussion from Linux ARM, DRM, IOMMU, and Freedreno maintainers and contributors. The local patches are adapted for the Linux 6.6 `linux-linaro-qcomlt` baseline and the IFC6410 Yocto BSP; they are not represented as an unchanged upstream patch series.

Primary upstream discussion and patch references:

- [PATCH v2 0/3: Fix GPU and display on ARM32 platforms using the MSM IOMMU](https://lkml.iu.edu/2607.3/13676.html)
- [PATCH v2 1/3: iommu/msm: track a context master per device and IOMMU](http://lists.infradead.org/pipermail/linux-arm-kernel/2026-July/1156397.html)
- [PATCH v2 2/3: iommu/msm: use the IOMMU device for page table allocation](https://lkml.org/lkml/2026/7/30/1922)
- [PATCH v2 3/3: drm/msm: detach the ARM DMA mapping before attaching our own domain](https://lists.freedesktop.org/archives/dri-devel/2026-July/585692.html)

---

## Firmware Notice

Firmware is intentionally excluded from this Git repository for licensing and redistribution reasons. The directory below is ignored by Git but must be populated locally before building an image that uses the affected hardware:

```text
meta-ifc6410/recipes-kernel/linux/files/firmware/
```

The local build has used firmware for the following devices:

- Atheros AR6004 Wi-Fi (`ath6k/AR6004/hw3.0/`), including `fw-5.bin` and calibrated board data.
- Atheros AR3K Bluetooth (`ar3k/`).
- Qualcomm Adreno 320 microcode (`qcom/a300_pfp.fw` and `qcom/a300_pm4.fw`).
- Realtek RTL815x Ethernet firmware (`rtl_nic/`).
- Wireless regulatory database (`regulatory.db` and `regulatory.db.p7s`).

Obtain and redistribute firmware only under its original vendor or distribution licensing terms. The source layer remains usable without committing these binary firmware files, but affected hardware requires them at runtime.

---

## Building

Run BitBake as a standard non-root user.

### Clone the Yocto sources

```bash
mkdir -p ~/yocto-ifc6410
cd ~/yocto-ifc6410

git clone -b scarthgap https://git.yoctoproject.org/poky
git clone -b scarthgap https://git.yoctoproject.org/meta-qcom poky/meta-qcom
git clone <your-meta-ifc6410-repository-url> poky/meta-ifc6410
```

### Initialize and configure the build

```bash
cd ~/yocto-ifc6410/poky
source oe-init-build-env build/qcom-armv7a

bitbake-layers add-layer ../meta-qcom
bitbake-layers add-layer ../meta-ifc6410

echo 'MACHINE = "qcom-armv7a"' >> conf/local.conf

bitbake-layers show-appends | grep -A 6 "linux-linaro-qcomlt"
```

Populate the local firmware directory described above before building if Wi-Fi, Bluetooth, GPU, Realtek Ethernet firmware, or the regulatory database are required.

### Build the kernel

```bash
bitbake virtual/kernel
```

Kernel images, DTBs, boot images, and modules are generated under:

```text
tmp/deploy/images/qcom-armv7a/
```

The IFC6410 boot image normally follows this pattern:

```text
boot-qcom-apq8064-ifc6410--6.6-r0-qcom-armv7a-<timestamp>.img
```

Build a full userspace image, if needed, with:

```bash
bitbake core-image-base
```

### Preserve the effective kernel config

`meta-ifc6410/recipes-kernel/linux/files/ifc6410.cfg` is an input fragment. The authoritative resolved configuration is the `.config` generated in the kernel recipe build directory:

```bash
cp tmp/work/qcom_armv7a-poky-linux-gnueabi/linux-linaro-qcomlt/6.6/build/.config \
   ifc6410-linux-6.6-effective.config
```

For the validated release in this repository, the effective configuration is retained at:

```text
releases/ifc6410-kernel-config-20260924-100651/ifc6410-linux-6.6-effective.config
```

---

## Flashing the IFC6410

Put the IFC6410 into fastboot mode, connect the board through micro-USB OTG, and use the **same timestamped boot image, DTB, and modules release set**.

Test boot into RAM:

```bash
fastboot boot boot-qcom-apq8064-ifc6410--6.6-r0-qcom-armv7a-20260924162336.img
```

Flash the eMMC boot partition:

```bash
fastboot flash boot boot-qcom-apq8064-ifc6410--6.6-r0-qcom-armv7a-20260924162336.img
```

Use the board's normal recovery method and keep a known-good image available before permanently flashing experimental builds.

---

## Hardware Verification

### MSM DRM and Adreno 320

After booting, confirm kernel bring-up:

```bash
dmesg -T | grep -Ei 'msm|adreno|iommu|smmu|fault|hang|reset|oops|panic'
ls -l /dev/dri
cat /sys/kernel/debug/dri/0/name 2>/dev/null || true
```

Expected kernel milestones include:

```text
mdp4 ...: bound 4300000.adreno-3xx (ops a3xx_ops)
[drm] Initialized msm ...
... loaded qcom/a300_pm4.fw ...
... loaded qcom/a300_pfp.fw ...
```

There must be no post-initialization MSM/Adreno/IOMMU fault, GPU hang, oops, or panic.

### Headless GPU verification

A monitor is not required. Verify both Mesa EGL paths over serial:

```bash
eglinfo -B -p surfaceless
eglinfo -B -p gbm
```

Expected hardware result:

```text
OpenGL ES profile vendor: freedreno
OpenGL ES profile renderer: FD320
OpenGL ES profile version: OpenGL ES 3.0 Mesa ...
```

`FD320` indicates Mesa selected the APQ8064 Adreno 320 GPU through Freedreno rather than using a software renderer such as llvmpipe.

### Other quick checks

```bash
# Hardware random-number generator
modprobe qcom-rng
grep -B 1 -A 8 "qcom-rng" /proc/crypto

# CPU and regulator-related messages
dmesg | grep -iE 'ncp|pm8921'
cat /proc/cpuinfo | grep processor
cat /sys/devices/system/cpu/cpu0/cpuidle/state1/name

# Wi-Fi firmware/driver
dmesg | grep -i ath6kl
ip link

# Storage layout
lsblk
```

Expected platform behavior:

- `qcom-rng` is available as a hardware entropy source.
- All four Krait cores are online; CPUIdle `spc` support is present when enabled by the active configuration.
- AR6004 Wi-Fi reports its firmware/API version and creates a `wlan0` interface when firmware is supplied.
- SATA storage appears as `/dev/sda`; eMMC appears as `/dev/mmcblk2` on the modern kernel.

---

## Known Limitations

- **CPU frequency scaling:** APQ8064 speed-bin/nvmem support required by `qcom-cpufreq-nvmem` is incomplete in this Linux 6.6 baseline. The CPUs operate at the bootloader-selected rate.
- **QCE crypto acceleration:** APQ8064 has CE4 hardware, while the mainline `qcrypto` driver expects later CE revisions. ARM optimized software crypto and the Qualcomm hardware RNG remain available.
- **Analog audio:** The onboard WCD9310/Taiko and APQ8064 SLIMbus/QDSP audio path are not fully supported by upstream mainline Linux. USB Audio Class adapters are the practical audio workaround.
- **HDMI audio:** An upstream LPASS CPU DAI path for APQ8064 HDMI audio is not available.
- **HDMI scanout:** MSM DRM and headless GPU rendering work, but physical HDMI output, connector detection, DDC, and HPD timing still require validation/further work.
- **GPU regulators and cooling:** The current device tree has no named GPU `vdd`/`vddcx` supplies, resulting in dummy-regulator messages. GPU devfreq cooling registration also remains unavailable. These are nonfatal for the tested headless GPU path.
- **Bluetooth:** The Atheros AR3002 controller on GSBI6 UART (`/dev/ttyMSM1`) remains under investigation.
