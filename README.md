# ifc6410
Repo for ifc6410 single-board-computer -

<p>archlinux: Current rolling release 20220828
<br>debian: jessie 8.11
<p>
Yocto kernel commands (kirkstone branch):
<br>$ cd poky
<br>$ git pull
<br>$ source oe-init-build-env
<br>$ cd /build
<br>$ bitbake-layers add-layer ../../meta-qcom
<br>$ bitbake -c menuconfig virtual/kernel       ##kernel config
<br>$ bitbake core-image-tiny-initramfs          ##rebuild distro
<br>$ bitbake -c compile -f virtual/kernel       ##rebuild only kernel
