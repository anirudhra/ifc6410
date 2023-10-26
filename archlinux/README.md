extract rootfs from linux host:
<br>bsdtar -xpf ArchLinuxARM-<version>.tar.gz -C <mount_point_root_target>
<br>
after install:
ssh (alarm:alarm), su (root:root)
<br>
pacman-key --init
<br>pacman-key --populate archlinuxarm
<br>pacman -Syu

