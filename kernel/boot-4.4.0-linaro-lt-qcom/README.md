# Kernel 4.4.x for IFC6410 (APQ8064)

All IPs onboard should work but this is a very old kernel and may not work with newer userspace/rootfs linux distributions. This is the last official linaro kernel: https://releases.linaro.org/debian/boards/snapdragon/16.02/

* Use appropriate kernel image for corresponding ROOTFS (emmc, usb/sata, sdcard etc.)
* Extract kernel modules to /lib/modules/<kernel> on rootfs: 4.4.0-linaro-lt-qcom.zip

