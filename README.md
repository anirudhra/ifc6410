# QCOM IFC6410 SBC with APQ8064 SoC

Repo for ifc6410 single-board-computer and custom kernel compile using Yocto/OpenEmbedded. See .../docs/* pins *.png files for pins to be used for fastboot and UART/Serial connection on the board.

## Kernel Compile

Yocto kernel commands (kirkstone branch builds kernel 5.15, use a newer branch like scarthgap for 6.6.x):
  
```
git clone git://git.yoctoproject.org/poky
cd poky
git checkout -t origin/kirkstone -b my-branch      ##scarthgap also works for 6.6.x
git pull
git clone git://git.yoctoproject.org/meta-qcom
cd meta-qcom
git checkout -t origin/kirkstone -b my-branch-qcom ##scarthgap also works for 6.6.x
cd .. #go back to poky directory
source oe-init-build-env
```

* Modify MACHINE ??="qemux86_64" in build/conf/local.conf to:

kirkstone branch (kernel 5.15.x):
```
MACHINE ??="ifc6410" ##change other settings like package_deb later etc., kirkstone branch only, kernel 5.15
```
scarthgap branch (kernel 6.6.x):
```
MACHINE ??="qcom-armv7a" ##change other settings like package_deb, state cache/mirror later etc., scarthgap branch only, kernel 6.6+
```

* Modify "/dev/mmcblk0p12" (old emmc userdata partition) to in meta-qcom/conf/machine/ifc6410.conf (or qcom-armv7a.conf) to new userdata emmc partition under QCOM_BOOTIMG_ROOTFS:
```
/dev/mmcblk0p13 #for new emmc userdata partition
```
...alternatively you can also change it to:
```
/dev/disk/by-partlabel/userdata
```
...or for SDCard:
```
/dev/mmcblk1p1 #or mmcblk1p2/p3... etc.
```
...or for USB/SATA:
```
/dev/sda1
```

* Compile kernel:
```
cd build
bitbake-layers add-layer ../meta-qcom              ##ensure /build/conf/bblayers.conf has meta-qcom entry
bitbake -c menuconfig virtual/kernel                  ##kernel config
bitbake core-image-minimal                            ##rebuild distro, no initramfs
bitbake -c compile -f virtual/kernel                  ##rebuild only kernel
```

## Kernel Settings

* Kernel/userspace compiled versions will be in .../build/tmp/deploy/images/ifc6410 or qcom-armv7a directory
* The ROOTFS change in .conf above sometimes does not work. Modify bootimg.cfg in boot-qcom-apq8064-ifc6410-....img to add following to commandline/boot config to override root: 

```
"cmdline = root=/dev/sda1 rw rootwait console=ttyMSM0,115200n8 systemd.unit=multi-user.target systemd.unified_cgroup_hierarchy=0 fw_devlink=permissive"
```
(or root=/dev/mmcblk0p13 or /dev/mmcblk1p1 etc.) 

...and repackage img with abootimg utility. To extract and make modifications above:
```
abootimg -x <kernelimg>
```
...to repackage:
```
abootimg -u <kernelimg> -f bootimg.cfg #bootimg.cfg should have updated kernel cmdline
```

* Blacklist msm module if necessary (GPU hangs, but disables display) to /etc/modprobe.d/blacklist.conf:
```
msm
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

## Kernel Modules, Firmware and EMMC Partitions

Kernel modules will be compiled and available in .../build/tmp/deploy/images/ifc6410 or qcom-armv7a directory. These need to match the kernel that is booted/flashed. Also, QCOM firmware is typically flashed to /dev/mmcblk0p15 parittion (a.k.a/labeled "cache" paritition). An archive of qcom-firmware image is available in custom_boot directory (for reference, as it only needs to be flashed once).

Both modules and firmware are necessary to be loaded (firmware either copied to rootfs /lib/firmware directory or /dev/mmcblk0p15 mounted as /lib/fimrware in fstab at boot) to work correctly.

See .../docs/part-table.png for original mappings, mounts and partition references for onboard EMMC.

## Wifi CLI connect

To connect to wifi from commandline, install nmcli:

```
nmcli dev wifi connect <mySSID> password <myPassword>
```
