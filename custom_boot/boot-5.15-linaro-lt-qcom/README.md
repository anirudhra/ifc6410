# Kernel 5.15.x: Custom compiled LTS kernel for IFC6410 (APQ8064)

LTS custom compiled LTS kernel on Yocto for IFC6410 (APQ8064). GPU does NOT work, audio is not detected either. Needs to be blacklisted before you boot. Most modern linux distribution userspace/rootfs should work with this kernel for quite a few years. Primary usage is headless server.

* Use appropriate kernel image for corresponding ROOTFS (emmc, usb/sata:sda1, sdcard etc.)
* Extract kernel modules to /lib/modules/<kernel> on rootfs: modules--5.15-r0-ifc6410-20220928021518.tgz
* Kernel .confg saved for future reference: kernel_config-5.15-r0-ifc6410-20220928021518
* Commandline saved for future reference (enabled cgroups for docker): cmdline.cfg
* Blacklist GPU in /etc/modprobe.d/blacklist.conf by adding (also in blacklist.conf):
```
msm
```
