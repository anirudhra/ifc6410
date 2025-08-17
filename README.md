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

This kernel does not have GPU/DPU/audio working. Loading "msm" GPU driver crashes the kernel/bootup. Make sure to blacklist "msm" modules at startup to prevent system bootup hangs.

```
git clone git://git.yoctoproject.org/poky
cd poky
git checkout -t origin/kirkstone -b mypokybranch
git pull
git clone git://git.yoctoproject.org/meta-qcom
cd meta-qcom
git checkout -t origin/kirkstone -b myqcombranch
cd ..
source oe-init-build-env build/qcom-armv7a
bitbake-layers add-layer ../../meta-qcom  # from within build/qcom-armv7a directory
```

* Change MACHINE ??="qemux86_64" in ../build/qcom-armv7a/conf/local.conf to:

```
MACHINE ??="ifc6410"      ## change other settings like package_deb, mirros etc. as necessary
```

* Change rootfs partition: "/dev/mmcblk0p12" (old emmc userdata partition) in .../poky/meta-qcom/conf/machine/ifc6410.conf to new userdata emmc partition under QCOM_BOOTIMG_ROOTFS:
```
/dev/mmcblk0p13           ## for emmc userdata partition
/dev/mmcblk1p1            ## for sdcard partition 1 or mmcblk1p2/p3 etc. depending on paritition number
/dev/sda1                 ## for USB port 1 (top) or SATA
```

### scarthgap branch (Kernel 6.6)

This kernel detects GPU/DPU and "can" load msm drivers without kernel crash but the HDMI port shows no output. The GPU driver "msm" need not be blacklisted. It has broken audio though.

```
git clone git://git.yoctoproject.org/poky
cd poky
git checkout -t origin/scarthgap -b mypokybranch
git pull
git clone git://git.yoctoproject.org/meta-qcom
cd meta-qcom
git checkout -t origin/scarthgap -b myqcombranch
cd ..
source oe-init-build-env build/qcom-armv7a
bitbake-layers add-layer ../../meta-qcom  # from within build/qcom-armv7a directory
```

* Change MACHINE ??="qemux86_64" in ../build/qcom-armv7a/conf/local.conf to:
```
MACHINE ??="qcom-armv7a"  ## change other settings like package_deb, mirror etc. as necessary
```

* Change rootfs paritition "/dev/mmcblk0p12" (old emmc userdata partition) in .../poky/meta-qcom/conf/machine/qcom-armv7a.conf to new userdata emmc partition under QCOM_BOOTIMG_ROOTFS:
```
/dev/mmcblk2p13          ## for emmc userdata partition which is now /dev/mmcblk2 in kernel 6.6
/dev/mmcblk0p1           ## for sdcard paritition 1 or mmcblk0p2/p3 depending on paritition number etc., also note sdcard is now /dev/mmcblk0 in kernel 6.6
/dev/sda1                ## for USB port 1 (top) or SATA
```

### Additional Kernel Command Line Parameters

To the the same local.conf from above, depending on the kernel version, add the following new line to the end of the file. This avoids having to use abootimg later to append custom command line:
```
KERNEL_CMDLINE_EXTRA ?= "systemd.unit=multi-user.target systemd.unified_cgroup_hierarchy=0 fw_devlink=permissive"
```

### Compile kernel (common to both branches)

* Add QCOM changes as described above and configure the following kernel configure/build options from within the /build/qcom-armv7a directory. Make sure to run the source-oe script with qcom-armv7a before running any of below for all subsequent builds.
```
bitbake -c menuconfig virtual/kernel                  ##kernel config
```
* To build kernel and distribution:
```
bitbake core-image-minimal                            ##rebuild distro, no initramfs
```
* To build only kernel:
```
bitbake -c compile -f virtual/kernel                  ##rebuild only kernel
```
* To save kernel defconfig file:
```
bitbake virtual/kernel -c savedefconfig
```

## Kernel Modules, Firmware and EMMC Partitions

Kernel modules will be compiled and available in .../build/tmp/deploy/images/ifc6410 (kirkstone branch) or .../images/qcom-armv7a (scarthgap branch) directory. These need to match the kernel that is booted/flashed (make sure to run "depmod -a" command from within the right /lib/modules directory for the modules to matched to the loaded kernel. Also, QCOM firmware is typically flashed to /dev/mmcblk0p15 parittion (a.k.a/labeled "cache" paritition) and sometimes mapped to /lib/firmware in fstab. An alternative/better way is to copy the firmware files directly to the rootfs partition's /lib/firmware locally (or /usr/lib/firmware depending on distribution).

Both modules and firmware are necessary to be loaded for the kernel and devices to function properly. Due to size limits, some versions of kernel modules may be split into multiple parts in this repo due to git file size restrictions. It's important to merge the contents of multiple archives in /lib/modules/<version>.

An archive of qcom-firmware image is available in custom_boot directory (for reference, as it only needs to be flashed once if mounting partition as /lib/firmware instead of copying files locally on rootfs' /lib/firmware directory - preferred way). See .../docs/part-table.png for original mappings, mounts and partition references for onboard EMMC.

The following device drivers need to be compiled as part of kernel (iommu, qcom soc-specific/iommu, usb, pcie, cgroups, fs, clock control etc.) or as modules:
* atl1c (Device Drivers > Network device support > Ethernet driver support): Atheros L1c onboard gigabit LAN
* r8152 USB LAN (Device Drivers > Network device support > USB Network Adapters): USB Realtek gigabit LAN for rtl8150/2/3
* ath6kl-sdio (Device Drivers > Network device support > Wireless LAN): Atheros 6000 onboard wifi (ath6lk-sdio, -core versions, also enable "blueooth coexistence")
* Bluetooth (Networking support > Bluetooth subsys support > Bluetooth device drivers): ath3k BT loader and protocols, also enable rfcomm/tty BT serial protocols 
* FileSystems: overlayfs, squashfs, jffs, exfat, fat32, ntfs including write support, btrfs, i/dnotify, Kernel Automounter, fuse 
* Control Group support (General setup): control/cgroups (for Docker), enable bpf for cgroups v2 (CONFIG_CGROUP_BPF, If not found, press the / key to open the search prompt and type CONFIG_CGROUP_BPF and press Enter)
* Networking support > Networking options: Ethernet bridging, Network packet filtering (netfilter), iptables, TCP/IP, IPv6, stp, llc, veth (for Docker)
* IOMMU (Device Drivers > IOMMU Hardware Support): msm-iommu (enable this instead of qualcomm/qcom-iommu preferably)
* Network FS (File Systems > Network file systems): cifs/smb/samba, nfsv4 for network sharing (client and server versions)
* USB Attached SCSI (UAS), OTG and Mass Storage (Device drivers > USB Support): for external HDDs, build these into the kernel NOT as modules, else rootfs mount will deadlock
* USB: Enable USB1.1, USB2.0 and 3.0 drivers, integrated into the kernel. USB 3.0 is needed for new USB hubs to connect to the SBC
* QCOM RPM, Krait CPU/thermal management, HFPLL, QCOM-SPM (dvfs) QCOM-SCM (security), TZ/QFPROM, qcom kpss clock controller etc. (see Device Drivers > SoC specific drivers > QCOM SoC and Device Drivers > Common Clock Framework > QCOM clock controllers)
* libata.force option (Device Drivers > Serial ATA and PATA): To set "noncq" kernel command line option for PCIe SATA SSDs 
* all other QCOM drivers for APQ8060/8064/8660/8960
* To support "iotop" utility, enable Kernel accounting: General setup > CPU task/time and stacs a/c > process accounting, expose thru netlink, I/O accounting, taskstats
* msm GPU (Device Drivers > Graphics Support): Adreno GPU "msm" driver MUST be built as a module instead of integrating into kernel in order to be able to blacklist later if it hangs
* PCie: Designware IP with some QCOM customizations
* I2C and Slimbus support (Device Drivers > SLIMBus and I2C): for Audio (currently not working in non-4.4 kernels)
* Local Version custom kernel version string (General Setup > Local version) can be set for ID (for e.g., "-<data>" with a leading hypen)
* Hostname (General Setup > Default hostname): can be set to "ifc6410"

Wifi firmare OG repo: https://github.com/qca/ath6kl-firmware/tree/master/ath6k/AR6004/hw3.0

Driver apq8064-tabla-snd-card/snd-apq8964 seems to be have been removed from kernel/sound in mainline, hence no audio support in the later kernels (5.x+).

### Built-in drivers and firmware

In some cases, it might be beneficial to integrate both drivers and firmware into the linux boot image. To integrate firmware:

* Create a pre-determined root directory, for e.g., /ifc6410/firmware
* Recreate directory structure of /lib/firmware with files in the correct place, for e.g., place rtl8152a-4.fw inside the root's .../rtl_nic subdirectory, and bdata/fw-5.bin for ath6k within .../ath6k/AR6004/hw3.0 subdirectory
* In kernel compile menuconfig, goto Device Drivers > Generic Driver Options > Firmware loader entry
* Under "Build named firmware blobs...", enter the exact relative path of firmware files, comma separated for multiple files, for e.g.:
```
ath6k/AR6004/hw3.0/bdata.bin ath6k/AR6004/hw3.0/fw-5.bin qcom/vidc_1080p.fw qcom/a300_pfp.fw qcom/a300_pm4.fw rtl_nic/rtl8153a-4.fw ath3k-1.fw regulatory.db regulatory.db.p7s
```
* Under "Firmware blobs root directory", enter the absolute path of the root directory created in first step above:
```
/ifc6410/firmware
```
* Ensure firmware files are readable by the user compiling the kernel. Absolute path of the firmware files on disk should be the concatenation of root directory and file mentioned above (for e.g., /ifc6410/firmware/rtl_nic/rtl8153a-4.fw)

To make kernel self-sufficient, apart from the firware files above, build the following drivers as built-in modules:

* atl1c: onboard AR8151 Ethernet
* ath6k: onboard WiFi
* 802.11 stack: cfg80211
* RTL 8152/3 USB ethernet

## Custom Kernel Command Line (post compile)

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

The option: ```systemd.unified_cgroup_hierarchy=0``` enables cgroups v1. Note that this is being deprecated in various distros. It is better to enable cgroup bpf support (CONFIG_CGROUP_BPF) for cgroups v2.

To disable SATA NCQ, additionally add the following to the above:
```
libata.force=noncq
```

The line root=/dev/sda1 will set rootfs as USB port 1/SATA as explained elsewhere in this readme. Other possible values are:

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
ath6lk_sdio
atl1c
```
* Use fastboot to test kernel, but ensure rootfs has corresponding kernel modules in /lib/modules/<kernel> and "depmod -a" command has been run:
```
fastboot boot <kernelimg>           ## to temporarily boot in to new kernel
fastboot flash boot <kernelimg>     ## to flash new kernel to boot partition
```
 
## Rootfs Bootstrapping with rsync

To bootstrap a new rootfs mounted at /mnt/rootfs from the currently booted system, use the bootstrap_rootfs.sh script under .../linux/common directory in the current repo.

## Prioritizing LAN over WLAN/WiFi

The WiFi firmware in the repo (latest available) lacks RSN override capability. As a result 802.11n (HT mode) cannot be enabled. WiFi is limited to 54Mbps (802.11g). Prioritizing LAN over WiFi still allows the WiFi to be connected all the time for a fallback (but slower) network.

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

References for WiFi firmware limitation:
* https://www.spinics.net/lists/ath6kl/msg00111.html
* https://www.spinics.net/lists/ath6kl/msg00112.html
* https://lists.infradead.org/pipermail/ath6kl/2015-July/000106.html
* https://www.spinics.net/lists/ath6kl/msg00091.html
* https://www.spinics.net/lists/linux-wireless/msg115085.html
* https://www.spinics.net/lists/linux-wireless/msg87931.html

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

## Docker bridge/iptables error

If you see an error similar to this:
```
docker failed to register "bridge" driver: failed to add jump rules to ipv4 NAT tables
```
Run these these commands to switch from iptables-nft to iptables-legacy that docker wants and restart:
```
$ sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
$ sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
```

## Power and GPIO Pin Layout, SATA 5V power

Some images from following websites are in <current_repo>/doc directory (Power/GPIO/SATA).

## SATA: Hard drive 

### SATA NCQ Errors in dmesg

Could be due to several causes including known offending SSDs like Samsung EVO or aggressive power management being enabled. Disable aggressive power management. Try "medium_power" for /sys/class/scsi_host/host0/link_power_management_policy to resolve the issue. If so, use the udev rule to set it on boot, available in <repo>/linux/common/etc/udev.

```
$ cat /etc/udev/rules.d/10-ssd-power-mode.rules
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="medium_power"

$ cat /sys/class/scsi_host/host0/link_power_management_policy
medium_power
```

NCQ can be disabled with the kernel command line "libata.force=noncq", a version for 6.6.x kernel is available in the repo. Alternatively, use the follow command to limit NCQ queue size to 1 in crontab and increase the timeout to 180sec (related to the problem but independent to NCQ):

```
$ crontab -e
@reboot echo 1 > /sys/block/sda/device/queue_depth
@reboot echo 180 > /sys/block/sda/device/timeout
```

### fsck error checking

Use the following command to automate check after every 5 mounts/reboots. Change /dev/sda1 to the correct partition and -c 5 to tweak the number of mounts/reboots accordingly.

```
partition=/dev/sda1; LC_ALL=C tune2fs -i 3600s -c 5 $partition 2>&1 | grep Setting
```

### SATA Throughput

USB ports don't appear to share bandwidth as USB LAN adapter gets the same speed regardless of SSD being connected through USB or now.

```
$ iperf3 -Rc pve.local
Connecting to host 10.100.100.50, port 5201
Reverse mode, remote host 10.100.100.50 is sending
[  5] local 10.100.100.64 port 57984 connected to 10.100.100.50 port 5201
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-1.00   sec  24.2 MBytes   203 Mbits/sec                  
[  5]   1.00-2.00   sec  24.4 MBytes   205 Mbits/sec                  
[  5]   2.00-3.00   sec  24.2 MBytes   203 Mbits/sec                  
[  5]   3.00-4.00   sec  24.1 MBytes   202 Mbits/sec                  
[  5]   4.00-5.00   sec  24.0 MBytes   201 Mbits/sec                  
[  5]   5.00-6.00   sec  24.1 MBytes   202 Mbits/sec                  
[  5]   6.00-7.00   sec  24.1 MBytes   202 Mbits/sec                  
[  5]   7.00-8.00   sec  24.3 MBytes   204 Mbits/sec                  
[  5]   8.00-9.00   sec  24.1 MBytes   202 Mbits/sec                  
[  5]   9.00-10.00  sec  24.2 MBytes   203 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-10.01  sec   243 MBytes   204 Mbits/sec    0             sender
[  5]   0.00-10.00  sec   242 MBytes   203 Mbits/sec                  receiver
```

#### USB-SATA Adapter

```
$ hdparm -Tt /dev/sda
/dev/sda: USB to SATA adapter
 Timing cached reads:   674 MB in  2.00 seconds = 337.48 MB/sec
 Timing buffered disk reads:  66 MB in  3.05 seconds =  21.63 MB/sec
```

#### SATA Native

```
$ hdparm -Tt /dev/sda
/dev/sda: SATA
 Timing cached reads:   720 MB in  2.00 seconds = 359.76 MB/sec
 Timing buffered disk reads: 326 MB in  3.00 seconds = 108.60 MB/sec
```

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
  
