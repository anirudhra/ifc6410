# Kernel 5.15.x: Custom compiled kernel

LTS custom compiled kernel on Yocto. GPU does NOT work, audio is not detected either. Needs to be blacklisted before you boot.

* Use appropriate kernel image for corresponding ROOTFS (emmc, usb/sata:sda1, sdcard etc.)
* Extract kernel modules to /lib/modules/<kernel> on rootfs: modules--5.15-r0-ifc6410-20220928021518.tgz
* Kernel .confg saved for future reference: kernel_config-5.15-r0-ifc6410-20220928021518
* Commandline saved for future reference (enabled cgroups for docker): cmdline.cfg
* Blacklist GPU in /etc/modprobe.d/blacklist.conf by adding (also in blacklist.conf):
```
msm
```
