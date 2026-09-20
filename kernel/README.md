# meta-ifc6410: Yocto BSP Layer for Inforce IFC6410 (APQ8064)

This custom Yocto layer contains board-specific kernel patches, machine configurations, hardware firmware, and configuration fragments for the **Inforce IFC6410** (Qualcomm Snapdragon S4 Pro / APQ8064) running Linux 6.6.y (`qcomlt`) on the Yocto `scarthgap` release.

Keeping these changes isolated inside `meta-ifc6410` allows upstream `poky` and `meta-qcom` to remain completely clean and tracking upstream Git branches without local merge conflicts.

---

## 1. Features and Deliverables

* **Machine Configuration (`conf/machine/qcom-armv7a.conf`):**
  * Target architecture: 32-bit ARMv7-A (`qcom-armv7a`).
  * Direct kernel command line (`APPEND`) targeting SATA rootfs (`/dev/sda1`), `libata.force=noncq`, unified cgroups v2, serial console on `ttyMSM0` at 115200 baud, and removal of initrd/ramdisk requirements.
* **Kernel Configuration Fragment (`recipes-kernel/linux/files/devfreq.cfg`):**
  * Core DRM bridge drivers (`CONFIG_DRM_DISPLAY_CONNECTOR=y`).
  * Atheros Ath6kl Wi-Fi driver modules (`CONFIG_ATH6KL=m`, `CONFIG_ATH6KL_SDIO=m`).
  * In-kernel CRDA wireless regulatory database and X.509 signature verification.
  * Atheros and Qualcomm Bluetooth HCI UART drivers (`CONFIG_BT_HCIUART_ATH3K=y`, `CONFIG_BT_HCIUART_QCA=y`, `CONFIG_BT_HCIUART_LL=y`).
* **Device Tree Patches (`recipes-kernel/linux/files/*.patch`):**
  * `0001-apq8064-ifc6410-add-hdmi-audio.patch`: Configures PM8921 voltage and frequency parameters for `pm8921_s2` (1.3V), `pm8921_s8` (2.05V), and enables the `pm8921_ncp` negative charge pump (1.8V) to resolve RPM regulator DT parsing failures.
  * `0001-ARM-dts-qcom-apq8064-Add-qfprom_physical-memory-reso.patch`: Adds the missing `qfprom_physical` MMIO register region (`<0x00700000 0x6100>`) to `hdmi: hdmi-tx@4a00000`.
* **Hardware Firmware (`recipes-kernel/linux/files/firmware/`):**
  * `ath6k/AR6004/hw3.0/`: Wi-Fi API 5 firmware (`fw-5.bin`) and calibrated board data (`bdata.bin`).
  * `qcom/`: Adreno 320 GPU microcode (`a300_pfp.fw`, `a300_pm4.fw`).
  * `regulatory.db` & `regulatory.db.p7s`: Signed wireless regulatory databases.
  * `rtl_nic/`: Realtek RTL8152/RTL8153 USB Ethernet firmware.
* **Recipe Extension (`recipes-kernel/linux/linux-linaro-qcomlt_%.bbappend`):**
  * Merges configuration fragments into the kernel build, stages hardware firmware directly into `${S}/firmware` and `${B}/firmware`, and applies the board device tree patches.

---

## 2. Repository Layout

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
        │   ├── devfreq.cfg
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
        └── linux-linaro-qcomlt_%.bbappend

3. Fresh Setup and Build Instructions

Follow these steps to set up a new build environment and build the kernel.
Step 3.1: Clone Upstream Repositories

Clone poky and meta-qcom tracking the scarthgap release:
Bash

mkdir -p ~/yocto-ifc6410 && cd ~/yocto-ifc6410
git clone -b scarthgap git://git.yoctoproject.org/poky
git clone -b scarthgap [https://git.linaro.org/landing-teams/working/qualcomm/meta-qcom.git](https://git.linaro.org/landing-teams/working/qualcomm/meta-qcom.git) poky/meta-qcom

Step 3.2: Place meta-ifc6410 in Poky

Copy or clone the meta-ifc6410 layer into the root of poky:
Bash

# If copying from an existing local repo:
cp -a /path/to/meta-ifc6410 ~/yocto-ifc6410/poky/

Step 3.3: Initialize Build Directory
Bash

cd ~/yocto-ifc6410/poky
source oe-init-build-env build/qcom-armv7a

Step 3.4: Register Layers in bblayers.conf
Bash

bitbake-layers add-layer ../meta-qcom
bitbake-layers add-layer ../meta-ifc6410

# Verify both layers appear in the active layer list:
bitbake-layers show-layers

Step 3.5: Configure Machine in local.conf

Ensure target machine is set in conf/local.conf:
Bash

echo 'MACHINE = "qcom-armv7a"' >> conf/local.conf

Step 3.6: Verify Recipe Extension

Confirm that BitBake automatically associates linux-linaro-qcomlt_%.bbappend with the kernel recipe:
Bash

bitbake-layers show-appends | grep -A 6 "linux-linaro-qcomlt"

Step 3.7: Compile the Kernel
Bash

bitbake virtual/kernel

The deployable fastboot image is located at:
tmp/deploy/images/qcom-armv7a/boot-qcom-apq8064-ifc6410-qcom-armv7a.img
4. Hardware Verification on IFC6410
Fastboot Booting

Put the IFC6410 into fastboot mode (reboot bootloader from serial console or power on with recovery jumper/button engaged) and boot the kernel:
Bash

fastboot boot tmp/deploy/images/qcom-armv7a/boot-qcom-apq8064-ifc6410-qcom-armv7a.img

1. Verify Power Regulators (NCP / S2 / S8)

Run:
Bash

dmesg | grep -iE 'ncp|pm8921'

Expected Result:

    The error driver callback failed to parse DT for regulator ncp must not appear.

    Regulators initialize cleanly with 1.8V NCP, 1.3V S2, and 2.05V S8 rails active.

2. Verify Wi-Fi (Atheros AR6004 SDIO)

Run:
Bash

dmesg | grep -i ath6kl

Expected Result:

    Firmware loads successfully without regulatory domain errors:
    ath6kl: ar6004 hw 3.0 sdio fw 3.5.0.349-1 api 5

    Interface wlan0 is created.

3. Verify Bluetooth (Atheros AR3002 UART on GSBI6)

The Atheros AR3002 Bluetooth controller connects via GSBI6 (/dev/ttyMSM1) with 4-pin hardware flow control.

Verify the kernel protocol driver is present:
Bash

modprobe hci_uart 2>/dev/null || true
dmesg | grep -i "hci uart protocol"

Expected Result: Bluetooth: HCI UART protocol Atheros (Ath3k) registered

Attach the controller:
Bash

hciattach -s 115200 /dev/ttyMSM1 ath3k 115200 flow

Expected Result: Device setup complete

Bring up the Bluetooth interface and initiate a scan:
Bash

hciconfig -a
hciconfig hci0 up
bluetoothctl scan on

Expected Result: Interface hci0 shows state UP RUNNING and actively discovers nearby Bluetooth advertisements.
4. Verify HDMI Display Pipeline Binding

Run:
Bash

dmesg | grep -i hdmi-tx

Expected Result:

    mdp4 5100000.display-controller: bound 4a00000.hdmi-tx (ops msm_hdmi_ops)
