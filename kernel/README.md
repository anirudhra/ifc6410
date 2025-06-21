# Kernels

Includes corresponding kernel modules to be put in rootfs' /lib/modules directory (dont' forget to run "depmod -a" after module/kernel change). Audio, BT and GPU work for kernel 4.4.x. None work for kernel 5.15 and only GPU is detected for kernel 6.6, but no console.

## Device naming

* Kernel 4.x/5.x - eth0: onboard ethernet, /dev/mmcblk0: emmc, /dev/mmcblk1: sdcard
* Kernel 6.x - enp1s0: onboard ethernet, /dev/mmcblk2: emmc, /dev/mmcblk0: sdcard
* USB - top port: /dev/sda1, bottom port: /dev/sda2

For the kernel with rootfs "sda1", if connecting SSD via USB, it should be connected to top port. Else, kernel command line needs to be accordingly modifidied and reflashed.

# Firmware

Backup of QCOM's firmware blob that either flashed to "cache" partition (emmc's mmcblk0p15) or copied to rootfs' /lib/firmware directory.

# Initrd: Custom (experimental)

Custom initrd image that allows multi-booting. Source: https://www.linuxquestions.org/questions/slackware-arm-108/munti-booting-ifc6410-4175528906/ and https://www.linuxquestions.org/questions/slackware-arm-108/inforce6410-ifc6410-single-board-computer-4175519873/

Unpacking it, will have 2 existing files in /conf that can be used as examples for adding more options. Repackage it after making changes and create a new kernel image and run/flash it via fastboot.

The init script looks in /conf and will display the options that it finds. A time out of 5 seconds is set and the default option is the second one (alphabetically). There is an extra option that will open up a shell in the initrd for debugging/recovery.

For the moment everything needs to boot with the same kernel but if kexec works it could be possible to boot different kernels, allowing for booting android along with ordinary linux distributions etc.

PS: There is a bug in init script in the initrd image. To fix it, add "umount /dev/pts" before the switch_root.
