# ifc6410
Repo for ifc6410 single-board-computer -

<p>archlinux: Current rolling release 20220828
<br>debian: jessie 8.11
<p>
Yocto kernel commands (kirkstone branch):
<br>$ git clone git://git.yoctoproject.org/poky
<br>$ cd poky
<br>$ git checkout -t origin/kirkstone -b my-kirkstone      ##langdale also works
<br>$ git pull
<br>$ git clone git://git.yoctoproject.org/meta-qcom
<br>$ cd meta-qcom
<br>$ git checkout -t origin/kirkstone -b my-kirkstone-qcom ##langdale also works
<br>$ source oe-init-build-env
<br>
<br>Modify MACHINE ??="ifc6410" in build/conf/local.conf    ##change other settings like package_deb etc.
<br>Modify "/dev/mmcblk0p12" to "/dev/mmcblk0p13" in meta-qcom/conf/machine/ifc6410.conf
<br>
<br>$ cd /build
<br>$ bitbake-layers add-layer ../../meta-qcom              ##ensure /build/conf/bblayers.conf has meta-qcom entry
<br>$ bitbake -c menuconfig virtual/kernel                  ##kernel config
<br>$ bitbake core-image-minimal                            ##rebuild distro, no initramfs
<br>$ bitbake -c compile -f virtual/kernel                  ##rebuild only kernel
<br>
<br>Kernel/userspace compiled versions in build/tmp/deploy/images/ifc6410. Modify boot-qcom-apq8064-ifc6410-....img to add following to commandline/boot config: "cmdline = root=/dev/sda1 rw rootwait console=ttyMSM0,115200n8 systemd.unit=multi-user.target systemd.unified_cgroup_hierarchy=0 fw_devlink=permissive" and repackage img with abootimg utility
<br> Blacklist msm module if necessary
