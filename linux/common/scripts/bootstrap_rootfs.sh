#!/bin/bash
# Script to bootstrap linux installation to a fresh storage device, mounted to /mnt/rootfs

# directory where the new bootstrap rootfs is mounted
ROOTFS="/mnt/rootfs"
#SOURCE="root@ifc6410:/"
SOURCE="/"

###################
echo "####################################################"
echo "Mount target to ${ROOTFS}"
echo "Stage 1: Copying ${SOURCE} to ${ROOTFS}"
read -p "Press any key to continue..."
echo "####################################################"
###################

#bootstrap stage 1 command:
rsync -avP --numeric-ids --exclude='/dev' --exclude='/proc' --exclude='/sys' ${SOURCE} ${ROOTFS}/

###################
echo "####################################################"
echo "Stage 2: Copy config files, modules, firmware etc."
read -p "Press any key to continue..."
echo "####################################################"
###################

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
#chroot ${ROOTFS}

# Debian: install following packages at the very least and then run dpkg-reconfigure tzdata, dpkg-reconfigure locales
# btop ssh ca-certificates tmux duf nano sudo console-setup console-setup-linux network-manager wget curl lsb-release locales iw net-tools systemd-timesyncd

###################
echo "#############################################################################################################################"
echo "Done! Manually chroot to ${ROOTFS} to verify and install standard packages like btop/ssh/ca-certificates etc." 
echo "#############################################################################################################################"
###################
