# QCOM IFC6410 SBC with APQ8064 SoC

Repo for IFC6410 single-board-computer (SBC) and custom kernel compile using Yocto/OpenEmbedded. See .../docs/img-* pins *.png files for pins to be used for fastboot and UART/Serial connection on the board. Most, if not all, kernel versions in the repo are LTS versions.

## UART/Serial connection

Set the following options:
* Configure the serial line:
* Speed (baud): 115200
* Data bits: 8
* Stop bits: 1
* Parity: none
* Flow control: none

## Kernel Compile

Yocto kernel MUST be compiled as nonroot user, else the bitbake build will fail. Note that only kernel 4.4.0 has all devices working. Beyond that kernel, audio is not detected and GPU hangs for all newer kernels (needs to be blacklisted explicitly, so ensure "msm" GPU driver is built as module and not integrated in to the kernel). All other devices work, so the SBC can be used as a headless computer.

For future updates, skip the "checkout" commands below and just "git pull".

After any changes to kernel or kernel modules, do not forget to run the following command to refresh the available kernel modules:

```
depmod -a
```

### kirkstone branch (Kernel 5.15)

```
git clone git://git.yoctoproject.org/poky
cd poky
git checkout -t origin/kirkstone -b mypokybranch
git pull
git clone git://git.yoctoproject.org/meta-qcom
cd meta-qcom
git checkout -t origin/kirkstone -b myqcombranch
cd ..
source oe-init-build-env
```
* Modify MACHINE ??="qemux86_64" in ../build/conf/local.conf to:

```
MACHINE ??="ifc6410"      ## change other settings like package_deb, mirros etc. as necessary
```

* Modify rootfs partition: "/dev/mmcblk0p12" (old emmc userdata partition) in .../poky/meta-qcom/conf/machine/ifc6410.conf to new userdata emmc partition under QCOM_BOOTIMG_ROOTFS:
```
/dev/mmcblk0p13           ## for emmc userdata partition
/dev/mmcblk1p1            ## for sdcard partition 1 or mmcblk1p2/p3 etc. depending on paritition number
/dev/sda1                 ## for USB or SATA
```

### scarthgap branch (Kernel 6.6)

```
git clone git://git.yoctoproject.org/poky
cd poky
git checkout -t origin/scarthgap -b mypokybranch
git pull
git clone git://git.yoctoproject.org/meta-qcom
cd meta-qcom
git checkout -t origin/scarthgap -b myqcombranch
cd ..
source oe-init-build-env
```

* Modify MACHINE ??="qemux86_64" in ../build/conf/local.conf to:
```
MACHINE ??="qcom-armv7a"  ## change other settings like package_deb, mirror etc. as necessary
```

* Modify rootfs paritition "/dev/mmcblk0p12" (old emmc userdata partition) in .../poky/meta-qcom/conf/machine/qcom-armv7a.conf to new userdata emmc partition under QCOM_BOOTIMG_ROOTFS:
```
/dev/mmcblk2p13          ## for emmc userdata partition which is now /dev/mmcblk2 in kernel 6.6
/dev/mmcblk0p1           ## for sdcard paritition 1 or mmcblk0p2/p3 depending on paritition number etc., also note sdcard is now /dev/mmcblk0 in kernel 6.6
/dev/sda1                ## for USB or SATA
```

### Compile kernel (common to both branches)

Add QCOM changes and configure kernel build options:
```
cd build
bitbake-layers add-layer ../meta-qcom                 ##ensure /build/conf/bblayers.conf has meta-qcom entry
bitbake -c menuconfig virtual/kernel                  ##kernel config
```
To build kernel and distribution:
```
bitbake core-image-minimal                            ##rebuild distro, no initramfs
```
To build only kernel:
```
bitbake -c compile -f virtual/kernel                  ##rebuild only kernel
```

## Kernel Modules, Firmware and EMMC Partitions

Kernel modules will be compiled and available in .../build/tmp/deploy/images/ifc6410 (kirkstone branch) or qcom-armv7a (scarthgap branch) directory. These need to match the kernel that is booted/flashed. Also, QCOM firmware is typically flashed to /dev/mmcblk0p15 parittion (a.k.a/labeled "cache" paritition) and sometimes mapped to /lib/firmware in fstab. An alternative/better way is to copy the firmware files directly to the rootfs partition's /lib/firmware locally (or /usr/lib/firmware depending on distribution).

Both modules and firmware are necessary to be loaded for the kernel and devices to function properly. Due to size limits, some versions of kernel modules may be split into multiple parts. It's important to merge the contents of multiple archives in /lib/modules/<version>.

An archive of qcom-firmware image is available in custom_boot directory (for reference, as it only needs to be flashed once if mounting partition as /lib/firmware instead of copying files locally on rootfs' /lib/firmware directory - preferred way). See .../docs/part-table.png for original mappings, mounts and partition references for onboard EMMC.

The following device drivers need to be compiled as part of kernel or as modules:
* atl1: Atheros L1 onboard gigabit LAN
* ath6k: Atheros 6000 onboard wifi (ath6lk-sdio, -core versions)
* overlayfs, iptables, netfilter, bridge, stp, llc, veth: For Docker
* r8152 usb: USB Realtek gigabit LAN
* ath3k bt: Atheros 3000 Bluetooth
* autofs (kernel automount), cifs, nfsv4: for network sharing
* QCOM RPM, Krait CPU/thermal management, qcom kpss clock controller
* all other QCOM drivers for APQ8060/8064/8660/8960
* msm: Adreno GPU "msm" driver MUST be built as a module instead of integrating into kernel in order to be able to blacklist later if it hangs
* PCie: Appears to be based on Designware IP with some QCOM customizations

Wifi firmare OG repo: https://github.com/qca/ath6kl-firmware/tree/master/ath6k/AR6004/hw3.0

Driver apq8064-tabla-snd-card/snd-apq8964 seems to be have been removed from kernel/sound in mainline, hence no audio support in the later kernels (5.x+).
 
## Kernel Boot Settings

Kernel/userspace compiled versions will be in .../build/tmp/deploy/images/ifc6410 (kirkstone branch) or qcom-armv7a directory (scarthgap branch). Compiled kernel will not have additional parameters needed for booting. Exactract bootimg.cfg from compiled boot image and manually override the kernel command line

To extract and make modifications as explaine above to packaged kernel image:
```
abootimg -x <kernelimg>
```
...to repackage:
```
abootimg -u <kernelimg> -f bootimg.cfg #bootimg.cfg should have updated kernel cmdline
```

Make the following change to "cmdline" line in bootimg.cfg. Do not modify any other line:
```
"cmdline = root=/dev/sda1 rw rootwait console=ttyMSM0,115200n8 systemd.unit=multi-user.target systemd.unified_cgroup_hierarchy=0 fw_devlink=permissive"
```
The line root=/dev/sda1 will set rootfs as USB/SATA as explained elsewhere in this readme. Other possible values are:

* Pre Kernel 6.6

```
/dev/mmcblk0p13           ## for emmc userdata partition
/dev/mmcblk1p1            ## for sdcard partition 1 or mmcblk1p2/p3 etc. depending on paritition number
```
* Kernel 6.6+

```
/dev/mmcblk2p13          ## for emmc userdata partition which is now /dev/mmcblk2 in kernel 6.6
/dev/mmcblk0p1           ## for sdcard paritition 1 or mmcblk0p2/p3 depending on paritition number etc., also note sdcard is now /dev/mmcblk0 in kernel 6.6
```

...and repackage img with "abootimg" utility. 

* Blacklist msm module if necessary (GPU hangs, but disables display) in the file /etc/modprobe.d/blacklist.conf:
```
blacklist msm
```
* Add wifi and onboard LAN drivers if necessary to /etc/modules:
```
ath6lk-sdio
atl1
```
* Use fastboot to test kernel, but ensure rootfs has corresponding kernel modules in /lib/modules/<kernel> and "depmod -a" command has been run:
```
fastboot boot <kernelimg>           ## to temporarily boot in to new kernel
fastboot flash boot <kernelimg>     ## to flash new kernel to boot partition
```

## SATA: Hard drive 

### SATA NCQ Errors in dmesg

Most likely due to power management being enabled. Disable aggressive power management. Try "medium_power" for /sys/class/scsi_host/host0/link_power_management_policy to resolve the issue. If so, use the udev rule to set it on boot, available in <repo>/linux/common/etc/udev.

### fsck error checking

Use the following command to automate check after every 5 mounts/reboots. Change /dev/sda1 to the correct partition and -c 5 to tweak the number of mounts/reboots accordingly.

```
partition=/dev/sda1; LC_ALL=C tune2fs -i 3600s -c 5 $partition 2>&1 | grep Setting
```

## Rootfs Bootstrapping with rsync

To bootstrap a new rootfs mounted at /mnt/rootfs from the currently booted system, use the bootstrap_rootfs.sh script under .../linux/common directory in the current repo.

## Prioritizing LAN over WLAN/WiFi

Use nmcli to set connection priorities
```
# List of connections
# You need to get the connection name (first column)
nmcli c

# Set the `ipv4.route-metric` of each required network
# Change the `$con_name_x` and integer as required
nmcli c mod "$con_name_1" ipv4.route-metric 20  # More preferred connection
nmcli c mod "$con_name_1" ipv6.route-metric 20  # More preferred connection
nmcli c mod "$con_name_2" ipv4.route-metric 40  # Less preferred connection
nmcli c mod "$con_name_2" ipv6.route-metric 40  # Less preferred connection

# Disconnect and reconnect the networks to make the changes effective
nmcli c down "$con_name_1"
nmcli c down "$con_name_2"
nmcli c up "$con_name_1"
nmcli c up "$con_name_2"

# Show connection priorities: example
nmcli -f ipv4.route-metric c show "$con_name_1"

# Check priorities in use: higher is listed on top for each direction
ip r
route -n #alternate command
```

## Wifi CLI connect

To connect to wifi from commandline, install NetworkManager package and run:

```
nmcli dev wifi connect <mySSID> password <myPassword>
```

## Onboard Ethernet

If ethernet/LAN is unstable, dropping down speed to 100mbps instead of 1000mbps may sometimes help. Install NetworkManager package for nmcli/nmtui utilties. Use following commands to reduce ethernet speed. If you have multiple ethernet adapters, make sure you are picking the correct connection.

```
nmcli c show
nmcli c edit "Wired connection 1"      # replace with the correct connection
goto ethernet
set auto-negotiate no
set speed 100
set duplex full
back
save persistent
quit
```

## GPIO

* 90 GPIO pins (GPIO_0 to GPIO_89)
* Configurable pull-up/down
* Configurable output drive current
* Interruptable GPIOs
* GPIO manipulation
* GPIO manipulation is done through the standard gpiolib

Additional useful links:
* http://elinux.org/GPIO
* https://developer.ridgerun.com/wiki/index.php/Gpio-int-test.c
* https://developer.ridgerun.com/wiki/index.php/How_to_use_GPIO_signals
* http://mondi.web.cs.unibo.it/gpio_control.html

### PinMux configuration

In older kernels, GPIO mux configuration is done in kernel/arch/arm/mach-msm/board-8064-gpiomux.c At apq8064_init_gpiomux(void) there are several examples of pinmux configuration (example struct apq8064_gsbi2_UART2_configs configures GPIO pins 22,23,24 and 25 to serial port).

### Generic serial bus interface (GSBI)

The APQ8064 implements 12 Generic Serial Bus Interface (GSBI) ports. GSBI ports can be configured for:

* UART_DM
* I2C
* SPI
* General-purpose I/O (GPIO) bits

## Power and GPIO Pin Layout, SATA 5V power

Some images from following websites are in <current_repo>/doc directory (Power/GPIO/SATA).

## Links/References related to IFC6410/APQ8064/QS600 SBC

* https://wiki.archlinux.org/title/Solid_state_drive#Resolving_NCQ_Errors (SATA NCQ errors)
* https://wiki.archlinux.org/title/Power_management#SATA_Active_Link_Power_Management
* https://awilby.gitbooks.io/cse-190-robotics/content/8_1_gpio.html
* https://www.hackster.io/inforce-ifc6410/projects
* https://github.com/freedreno/freedreno/wiki/Inforce-6410-Plus
* https://github.com/96boards/documentation/wiki/Dragonboard-Boot-Image
* https://releases.linaro.org/debian/boards/snapdragon/16.02/
* https://github.com/apq8064-mainline/linux
* http://pragmatux.com/docs/quick-start-ifc6410.html
* https://github.com/freedreno/freedreno/wiki/Inforce-6410-Plus
* https://www.spinics.net/lists/devicetree/msg473167.html
* https://www.compulab.com/products/computer-on-modules/cm-qs600/#devres
* https://www.compulab.com/products/sbcs/sbc-qs600/#devres
* https://www.compulab.com/cm-qs600-software-archive/
* https://mediawiki.compulab.com/w/index.php?title=CM-QS600_Qualcomm_Snapdragon_600_APQ8064_SW_Resources
* https://github.com/compulab/cm-qs600-kernel
* https://www.compulab.com/wp-content/uploads/2014/05/CM-QS600-Press-Release.pdf
* https://github.com/compulab/cm-qs600-android-device
* https://variwiki.com/index.php?title=VAR-SOM-SD600
* https://www.variscite.com/product/system-on-module-som/cortex-a53-krait/var-som-sd600-cpu-qualcomm-snapdragon600/#documentation
* https://variwiki.com/index.php?title=VAR-SOM-SD600_gpio
* https://github.com/compulab/eeprom-util
* https://mediawiki.compulab.com/w/index.php?title=Android:_Boot_image
* https://patchwork.ozlabs.org/project/openwrt/patch/1423622295-17130-1-git-send-email-mathieu@codeaurora.org/ (kpcc acc v1)
* https://mediawiki.compulab.com/w/index.php?title=CM-QS600:_Linux:_Debian (bluetooth, devices etc. config)
  
