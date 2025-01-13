# ifc6410

Repo for ifc6410 single-board-computer and custom kernel compile using Yocto/OpenEmbedded. See .../docs/*pins*.png files for pins to be used for fastboot and UART/Serial connection on the board.

<p>archlinux: Current rolling release 20220828
<br>debian: jessie 8.11
<p>
Yocto kernel commands (kirkstone branch builds kernel 5.15, use a newer branch like scarthgap for 6.6.x):
  
```
git clone git://git.yoctoproject.org/poky
cd poky
git checkout -t origin/kirkstone -b my-branch      ##langdale also works
git pull
git clone git://git.yoctoproject.org/meta-qcom
cd meta-qcom
git checkout -t origin/kirkstone -b my-branch-qcom ##langdale also works
cd .. #go back to poky directory
source oe-init-build-env
```

* Modify MACHINE ??="qemux86_64" in build/conf/local.conf to:
```
MACHINE ??="ifc6410" ##change other settings like package_deb etc., scarthgap and newer release only support "qcom-armv7a" for machine not ifc6410 as all boards are included in it
```
* Modify "/dev/mmcblk0p12" (old emmc userdata partition) to in meta-qcom/conf/machine/ifc6410.conf to new userdata emmc partition: (does not seem to exist in newer repos scarthgap, and instead it's shown as ROOT_FS)
```
/dev/mmcblk0p13
```
...alternatively you can also change it to:
```
/dev/disk/by-partlabel/userdata
```

To boot from USB/SDcard instead change it to:

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

* Kernel/userspace compiled versions in build/tmp/deploy/images/ifc6410
* Modify boot-qcom-apq8064-ifc6410-....img to add following to commandline/boot config: 

```
"cmdline = root=/dev/sda1 rw rootwait console=ttyMSM0,115200n8 systemd.unit=multi-user.target systemd.unified_cgroup_hierarchy=0 fw_devlink=permissive"
```

...and repackage img with abootimg utility
* Blacklist msm module if necessary (GPU hangs, but disables display)

## Wifi CLI connect

To connect to wifi from commandline:

```
nmcli dev wifi connect <mySSID> password <myPassword>
```
