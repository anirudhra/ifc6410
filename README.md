# ifc6410
Repo for ifc6410 single-board-computer -

<p>archlinux: Current rolling release 20220828
<br>debian: jessie 8.11

Yocto kernel commands:
$ cd poky
$ git pull
$ source oe-init-build-env
$ cd /build
$ bitbake-layers add-layer ../../meta-qcom
$ bitbake -c menuconfig virtual/kernel
$ bitbake core-image-tiny-initramfs
