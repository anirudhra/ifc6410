# Debian Linux userspace for IFC6410
   
* Stage 1: Install debootstrap_<ver>.deb package on host system
* Mount destination (target) rootfs system, for e.g., in /mnt/rootfs
* Bootstrap minimal debian install:
```
debootstrap --arch armhf stable /mnt https://deb.debian.org/debian
```  
* Stage 2: setup system directories and chroot:                                 
```
mount --make-rslave --rbind /proc /mnt/rootfs/proc
mount --make-rslave --rbind /sys /mnt/rootfs/sys
mount --make-rslave --rbind /dev /mnt/rootfs/dev
mount --make-rslave --rbind /run /mnt/rootfs/run
chroot /mnt/rootfs
```
* Add kernel modules directory and firmware directories/files
* Add required modules to /etc/modules and blacklist to /etc/modprobe.d/blacklist.conf
* See https://www.debian.org/releases/bullseye//i386/apds03.en.html and https://austinjadams.com/blog/install-debian-with-debootstrap/ for more details and other necessary steps

## Docker

Debian does not use iptables by default. Docker will fail. Run the following command and then restart docker service:
```
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
```
