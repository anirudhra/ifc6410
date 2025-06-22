# Arch Linux rootfs/userspace/bootstrap

* Extract rootfs from linux host:
```
bsdtar -xpf ArchLinuxARM-<version>.tar.gz -C <mount_point_root_target>
```
* Stage 2 bootstrap may need to be done after chrooting in to the mountpoint (for /proc and other directories), check documentation (check "debian" directory in this repo for creating sysfs like proc etc. on new rootfs and other details)

* After install:
```
ssh (alarm:alarm), su (root:root)
```

* Pacman keys:
```
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syu
```

