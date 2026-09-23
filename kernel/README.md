# meta-ifc6410: Yocto BSP Layer for Inforce IFC6410 (APQ8064)

This Yocto BSP layer provides hardware enablement, kernel configuration fragments, device tree fixes, and essential firmware for the **Inforce IFC6410** single-board computer (Qualcomm Snapdragon S4 Pro / APQ8064 Krait 300) running **Linux 6.6.y (`linux-linaro-qcomlt`)** on the Yocto Project **`scarthgap`** release.

Placing these board-specific customizations inside `meta-ifc6410` allows upstream `poky` and `meta-qcom` to track their respective Git branches cleanly without merge conflicts or local tree modifications.

---

## 1. What This Layer Adds Over Vanilla `meta-qcom`

Upstream `meta-qcom` provides generic `qcom-armv7a` baseline support for 32-bit Qualcomm targets, but the IFC6410 requires specific platform plumbing:

1. **CPUFreq Bootloader Pinning & CPUIdle Support:**
   * Upstream mainline Linux 6.6 lacks the necessary Device Tree OPP tables and speed-bin efuse wiring (`nvmem-cells`) for APQ8064 Krait cores, causing `qcom-cpufreq-nvmem` to fail during probe with `-ENOENT` (`-2`).
   * `meta-ifc6410` disables `CONFIG_ARM_QCOM_CPUFREQ_NVMEM`, preventing driver probe errors and allowing the four Krait cores to run stably at the bootloader-initialized performance ceiling.
   * Low idle temperatures are maintained through the Sawtooth Power Manager (SPM) driver and Standalone Power Collapse (`spc`), which dynamically gates clocks and cuts power rails to idle cores.
2. **Hardware Cryptography & RNG Enablement:**
   * Enables `CONFIG_CRYPTO_DEV_QCOM_RNG=m` (`qcom-rng`), hooking the APQ8064 on-chip PRNG hardware (`qcom,prng` at `0x1a500000`) into the kernel Crypto API as the primary system `stdrng`.
   * Enables ARM NEON/assembly-optimized symmetric crypto (`aes-arm-bs`, `sha256-arm`) in the kernel.
3. **Silencing Bogus Sensor Warnings:**
   * The IFC6410 PCB does not populate a Bosch BMP085/BMP280 barometer.
   * `meta-ifc6410` disables `CONFIG_BMP280` (`_SPI` and `_I2C`), preventing driver registration warnings (`SPI driver bmp280 has no spi_device_id for bosch,bmp085`) and saving boot cycles.
4. **Power Management & PM8921 Regulator Overrides:**
   * Upstream 6.6 DT triggers probe errors parsing RPM regulators. A DTS patch sets explicit voltages for `pm8921_s2` (1.3V), `pm8921_s8` (2.05V), and forces the `pm8921_ncp` negative charge pump (1.8V) to resolve regulator registration failures.
5. **QFPROM MMIO Resource Mapping:**
   * Fixes missing `qfprom_physical` address region (`<0x00700000 0x6100>`) under the HDMI TX node in `qcom-apq8064.dtsi`.
6. **Direct Bootloader Command Line Configuration:**
   * Overrides `APPEND` in `conf/machine/qcom-armv7a.conf` to target the default root disk on SATA/USB (`/dev/sda1`), enforces SATA non-queued commands (`libata.force=1.5Gbps,noncq`), sets unified cgroups v2 (`systemd.unified_cgroup_hierarchy=1`), enables `fw_devlink=permissive`, and routes the serial console to `ttyMSM0` at 115200 baud without needing manual `abootimg` repacking.
7. **802.11n Enablement:**
   * Overrides the no-HT bit in the `ath6kl` driver, enabling 802.11n high-throughput support on the AR6004 chipset that upstream firmware otherwise leaves unadvertised.
8. **Integrated Onboard Firmware Blobs:**
   * Ships and stages essential non-redistributable firmware:
     * Atheros AR6004 Wi-Fi: FW API 5 (`fw-5.bin`) and calibrated board data (`bdata.bin`).
     * Adreno 320 GPU microcode: `a300_pfp.fw` and `a300_pm4.fw`.
     * Realtek USB Gigabit Ethernet: RTL8152/RTL8153 firmware.
     * Wireless Regulatory Database (`regulatory.db` and signature).

---

## 2. Platform Constraints & Realities (Kernel 6.6)

* **Hardware Crypto Engine (`qce` / `qcrypto`):**
  * The mainline kernel driver `qcrypto` (`drivers/crypto/qce`) is hardcoded to require Qualcomm Crypto Engine (CE) v5.1+ (`major == 5 && minor > 0`).
  * APQ8064 utilizes **CE version 4** (CE4), so the mainline `qce` driver will reject it at runtime with `-ENODEV`. Asymmetric and symmetric operations rely on ARM NEON/assembly implementations, while the hardware PRNG (`qcom-rng`) provides genuine on-chip entropy.
* **CPU DVFS vs. CPUIdle:**
  * Mainline kernel lacks the nvmem speed-bin bindings required by `qcom-cpufreq-nvmem`. The CPU operates at the bootloader-selected static frequency.
  * Idle temperature drops are achieved via CPUIdle state 1 (`spc` / Standalone Power Collapse), which completely powers down idle cores.
* **Audio:**
  * **Analog (Headphone/Mic):** The IFC6410 onboard codec is the Qualcomm **WCD9310 (Taiko)** connected over SLIMbus. Upstream mainline Linux does not have a driver for WCD9310 or the APQ8064 QDSP4/LPASS SLIMbus audio engine. Native 3.5mm analog audio is therefore unavailable under mainline 6.6.
  * **HDMI Audio:** While the HDMI transmitter codec driver (`CONFIG_SND_SOC_HDMI_CODEC`) is enabled, APQ8064 lacks an upstream LPASS CPU DAI driver to feed PCM samples into HDMI FIFO.
  * **Workaround:** For audio output or input, use any standard USB Audio Class (UAC1/UAC2) adapter; `CONFIG_SND_USB_AUDIO=y` works out of the box.
* **MMC Device Indexing (6.6 vs. 4.x):**
  * On modern kernels, the SD card registers as `/dev/mmcblk0`, and onboard eMMC registers as `/dev/mmcblk2` (the userdata partition is `/dev/mmcblk2p13`).
* **GPU / Display / HDMI Output (Not Working / Under Debug):**
  * The `msm` DRM driver and Adreno 320 firmware load without crashing the kernel, but the HDMI transmitter fails to output a display signal. GPU display plumbing and DDC/HPD timing are non-functional and currently under active debugging.
* **Bluetooth (Not Working / Under Debug):**
  * The Atheros AR3002 Bluetooth controller connected via GSBI6 UART (`/dev/ttyMSM1`) does not currently initialize or complete firmware handshakes cleanly via `hciattach`. Bluetooth support is non-functional and under active investigation.

---

## 3. Repository Layout

```text
meta-ifc6410/
├── conf/
│   ├── layer.conf
│   └── machine/
│       └── qcom-armv7a.conf
└── recipes-kernel/
    └── linux/
        ├── files/
        │   ├── 0001-ARM-dts-qcom-apq8064-Add-qfprom_physical-memory-reso.patch
        │   ├── 0001-apq8064-ifc6410-add-hdmi-audio.patch
        │   ├── ifc6410.cfg
        │   └── firmware/
        │       ├── ath6k/
        │       │   └── AR6004/
        │       │       └── hw3.0/
        │       │           ├── bdata.bin
        │       │           └── fw-5.bin
        │       ├── qcom/
        │       │   ├── a300_pfp.fw
        │       │   └── a300_pm4.fw
        │       ├── regulatory.db
        │       ├── regulatory.db.p7s
        │       └── rtl_nic/
        │           ├── rtl8152a-4.fw
        │           └── rtl8153a-4.fw
        └── linux-linaro-qcomlt_%.bbappend
```

---

## 4. Setup and Build Instructions

Always run BitBake builds as a standard, non-root user.

### Step 4.1: Clone Upstream Repositories

Create your root workspace and clone `poky` and `meta-qcom` tracking the `scarthgap` branch:

```bash
mkdir -p ~/yocto-ifc6410 && cd ~/yocto-ifc6410
git clone -b scarthgap [https://git.yoctoproject.org/poky](https://git.yoctoproject.org/poky)
git clone -b scarthgap [https://git.yoctoproject.org/meta-qcom](https://git.yoctoproject.org/meta-qcom) poky/meta-qcom
```

### Step 4.2: Add `meta-ifc6410` Layer

Clone or copy this `meta-ifc6410` repository directly into `poky/` alongside `meta-qcom`:

```bash
# If using git:
git clone <your-meta-ifc6410-repo-url> poky/meta-ifc6410

# Or if copying from an existing local path:
cp -a /path/to/meta-ifc6410 poky/
```

### Step 4.3: Initialize Build Environment

Initialize the build directory for the `qcom-armv7a` machine target:

```bash
cd ~/yocto-ifc6410/poky
source oe-init-build-env build/qcom-armv7a
```

### Step 4.4: Register Layers in `bblayers.conf`

Add both `meta-qcom` and `meta-ifc6410` to your active build configuration:

```bash
bitbake-layers add-layer ../meta-qcom
bitbake-layers add-layer ../meta-ifc6410

# Verify active layers:
bitbake-layers show-layers
```

### Step 4.5: Configure `local.conf`

Set the target machine architecture in `conf/local.conf`:

```bash
echo 'MACHINE = "qcom-armv7a"' >> conf/local.conf
```

Verify that BitBake binds your bbappend to the kernel recipe:

```bash
bitbake-layers show-appends | grep -A 6 "linux-linaro-qcomlt"
```

### Step 4.6: Compile the Kernel

Trigger the kernel build:

```bash
bitbake virtual/kernel
```

The fastboot bootable Android image (`boot.img`) and kernel binaries are output to:

```text
tmp/deploy/images/qcom-armv7a/boot-qcom-apq8064-ifc6410-qcom-armv7a.img
```

To build a full userspace root filesystem:

```bash
bitbake core-image-base
```

---

## 5. Booting and Hardware Verification

### Fastboot Booting

Put the IFC6410 into fastboot mode (reboot to bootloader via serial console or power on with recovery jumper/button held), connect micro-USB OTG to your host PC, and test-boot into RAM:

```bash
fastboot boot tmp/deploy/images/qcom-armv7a/boot-qcom-apq8064-ifc6410-qcom-armv7a.img
```

To flash permanently to the onboard eMMC `boot` partition:

```bash
fastboot flash boot tmp/deploy/images/qcom-armv7a/boot-qcom-apq8064-ifc6410-qcom-armv7a.img
```

### Verification Checklist

1. **Hardware Random Number Generator (PRNG):**

   ```bash
   modprobe qcom-rng
   grep -B 1 -A 8 "qcom-rng" /proc/crypto
   ```

   * *Expected Result:* `qcom-rng` is registered as `stdrng` with `priority: 300` and `selftest: passed`, feeding hardware entropy to `/dev/urandom`.

2. **CPU Clocks & Regulators:**

   ```bash
   dmesg | grep -iE 'ncp|pm8921'
   cat /proc/cpuinfo | grep processor
   ```

   * *Expected Result:* Regulators initialize cleanly without DT parsing errors for `pm8921_ncp`. All 4 Krait cores are online.
   * Verify CPUIdle Standalone Power Collapse (`spc`) is active:

     ```bash
     cat /sys/devices/system/cpu/cpu0/cpuidle/state1/name
     ```

3. **Sensors / Clean Bootlog:**

   ```bash
   dmesg | grep -i bmp
   ```

   * *Expected Result:* Zero warnings regarding `SPI driver bmp280 has no spi_device_id`.

4. **Onboard Wi-Fi (Atheros AR6004 SDIO):**

   ```bash
   dmesg | grep -i ath6kl
   ```

   * *Expected Result:* Driver reports `ath6kl: ar6004 hw 3.0 sdio fw 3.5.0.349-1 api 5`, and interface `wlan0` appears in `ip link`.

5. **Storage & Disk Devices:**

   ```bash
   lsblk
   ```

   * *Expected Result:* SATA SSD registers under `/dev/sda`, external USB drives mount via UAS/Mass-Storage, and eMMC partitions show under `/dev/mmcblk2`.
