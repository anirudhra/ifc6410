# Kernels

Various kernels for IFC6410, some with all IPs working (4.4.0), others not (5.15 - no GPU/audio). Includes corresponding kernel modules to be put in rootfs' /lib/modules directory.

Note that pre-kernel 6.6.x, ethernet was eth0, internal EMMC was /dev/mmcblk0 and sdcard was /dev/mmcblk1. In Kernel 6.6 and beyond, ethernet is enp1s0, internal EMMC is /dev/mmcblk2 and sdcard is /dev/mmcblk0. Wifi continues to be wlan0 in both.

The change in emmc and sdcard device names, kernel command line will need to change accordingly for rootfs.

# Firmware

Backup of QCOM's firmware blob that either flashed to "cache" partition (emmc's mmcblk0p15) or copied to rootfs' /lib/firmware directory.

# Initrd: Custom (experimental)

Custom initrd image that allows multi-booting. Source: https://www.linuxquestions.org/questions/slackware-arm-108/munti-booting-ifc6410-4175528906/ and https://www.linuxquestions.org/questions/slackware-arm-108/inforce6410-ifc6410-single-board-computer-4175519873/

Unpacking it, will have 2 existing files in /conf that can be used as examples for adding more options. Repackage it after making changes and create a new kernel image and run/flash it via fastboot.

The init script looks in /conf and will display the options that it finds. A time out of 5 seconds is set and the default option is the second one (alphabetically). There is an extra option that will open up a shell in the initrd for debugging/recovery.

For the moment everything needs to boot with the same kernel but if kexec works it could be possible to boot different kernels, allowing for booting android along with ordinary linux distributions etc.

PS: There is a bug in init script in the initrd image. To fix it, add "umount /dev/pts" before the switch_root.
