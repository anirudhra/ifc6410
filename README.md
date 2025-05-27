# QCOM IFC6410 SBC with APQ8064 SoC

Repo for IFC6410 single-board-computer (SBC) and custom kernel compile using Yocto/OpenEmbedded. See .../docs/img-* pins *.png files for pins to be used for fastboot and UART/Serial connection on the board. Most, if not all, kernel versions in the repo are LTS versions.

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
MACHINE ??="ifc6410"      ##change other settings like package_deb, mirros etc. as necessary
```
* Modify rootfs partition: "/dev/mmcblk0p12" (old emmc userdata partition) in .../poky/meta-qcom/conf/machine/ifc6410.conf to new userdata emmc partition under QCOM_BOOTIMG_ROOTFS:
```
/dev/mmcblk0p13 #for new emmc userdata partition
```
...or for SDCard:
```
/dev/mmcblk1p1 #or mmcblk1p2/p3 etc. depending on paritition number
```
...or for USB/SATA:
```
/dev/sda1
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
MACHINE ??="qcom-armv7a" ##change other settings like package_deb, mirror etc. as necessary
```
* Modify rootfs paritition "/dev/mmcblk0p12" (old emmc userdata partition) in .../poky/meta-qcom/conf/machine/qcom-armv7a.conf to new userdata emmc partition under QCOM_BOOTIMG_ROOTFS:
```
/dev/mmcblk2p13 #for new emmc userdata partition, also emmc is now /dev/mmcblk2 in kernel 6.6
```
...or for SDCard:
```
/dev/mmcblk0p1 #or mmcblk0p2/p3 depending on paritition number etc., also note sdcard is now /dev/mmcblk0 in kernel 6.6
```
...or for USB/SATA:
```
/dev/sda1
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

Wifi firmare OG repo: https://github.com/qca/ath6kl-firmware/tree/master/ath6k/AR6004/hw3.0
 
## Kernel Boot Settings

* Kernel/userspace compiled versions will be in .../build/tmp/deploy/images/ifc6410 (kirkstone branch) or qcom-armv7a directory (scarthgap branch)
* The ROOTFS change in .conf above sometimes does not work. Modify bootimg.cfg in boot-qcom-apq8064-ifc6410-....img to add following to command line/boot config to override root to boot from USB/SATA (or corresponding rootfs for internal emmc/sdcard):

```
"cmdline = root=/dev/sda1 rw rootwait console=ttyMSM0,115200n8 systemd.unit=multi-user.target systemd.unified_cgroup_hierarchy=0 fw_devlink=permissive"
```
* Replace with root=/dev/mmcblk0p13 or /dev/mmcblk1p1 for pre-kernel 6.6 
* Replace root=/dev/mmcblk2p13 or /dev/mmcblk0p1 for kernel 6.6+

...and repackage img with "abootimg" utility. 

To extract and make modifications as explaine above to packaged kernel image:
```
abootimg -x <kernelimg>
```
...to repackage:
```
abootimg -u <kernelimg> -f bootimg.cfg #bootimg.cfg should have updated kernel cmdline
```

* Blacklist msm module if necessary (GPU hangs, but disables display) to /etc/modprobe.d/blacklist.conf:
```
blacklist msm
```
* Add wifi and onboard LAN drivers if necessary to /etc/modules:
```
ath6lk-sdio
atl1
```
* Use fastboot to test kernel, but ensure rootfs has corresponding kernel modules in /lib/modules/<kernel>:
```
fastboot boot <kernelimg>
```
* Use fastboot to finally flash working kernel, but ensure rootfs has corresponding kernel modules in /lib/modules/<kernel> as before:
```
fastboot flash boot <kernelimg>
```

## Rootfs Bootstrapping with rsync

To bootstrap a new rootfs mounted at /mnt/rootfs from the currently booted system, use the bootstrap_rootfs.sh script under .../linux/common directory in the rep

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

## Power and GPIO Pin Layout, SATA 5V power

Some images from following website are inside <repo>/doc directory (Power/GPIO/SATA).

## Links/References related to IFC6410/APQ8064

* https://awilby.gitbooks.io/cse-190-robotics/content/8_1_gpio.html
* https://www.hackster.io/inforce-ifc6410/projects
* https://github.com/freedreno/freedreno/wiki/Inforce-6410-Plus
* https://github-wiki-see.page/m/96boards/documentation/wiki/Dragonboard-Boot-Image
* https://releases.linaro.org/debian/boards/snapdragon/16.02/
* https://github.com/apq8064-mainline/linux
* http://pragmatux.com/docs/quick-start-ifc6410.html
* https://github.com/freedreno/freedreno/wiki/Inforce-6410-Plus
* https://www.spinics.net/lists/devicetree/msg473167.html
