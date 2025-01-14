#!/bin/bash

# directory where the new bootstrap rootfs is mounted
ROOTFS="/mnt/rootfs"

# create stage 2 sys directories
mount --make-rslave --rbind /proc ${ROOTFS}/proc
mount --make-rslave --rbind /sys ${ROOTFS}/sys
mount --make-rslave --rbind /dev ${ROOTFS}/dev
mount --make-rslave --rbind /run ${ROOTFS}/run

# copy some skeletal files to get started
cp /etc/fstab ${ROOTFS}/etc/fstab
cp -a /etc/ssh/sshd_config ${ROOTFS}/etc/ssh/sshd_config
cp -a /etc/ssh/ssh_config ${ROOTFS}/etc/ssh/ssh_config
cp -a /etc/NetworkManager ${ROOTFS}/etc/NetworkManager

# modules and firmware
mkdir -p ${ROOTFS}/lib/modules
mkdir -p ${ROOTFS}/lib/firmware
cp -a /lib/modules/* ${ROOTFS}/lib/modules/
cp -a /lib/firmware/* ${ROOTFS}/lib/firmware/

# copy included files in this repo's /etc to rootfs
cp -a ./etc/* ${ROOTFS}/etc/

# chroot to new install
chroot ${ROOTFS}

# install following packages at the very least
# btop ssh ca-certificates tmux duf nano sudo console-setup console-setup-linux network-manager wget curl lsb-release locales iw net-tools ntp systemd-resolvd
# configure: dpkg-reconfigure tzdata, dpkg-reconfigure locales
