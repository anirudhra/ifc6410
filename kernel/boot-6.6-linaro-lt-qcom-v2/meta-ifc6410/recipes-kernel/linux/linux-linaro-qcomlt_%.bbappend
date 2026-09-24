INITRAMFS_IMAGE = ""
INITRAMFS_IMAGE_BUNDLE = "0"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://ifc6410.cfg \
            file://0001-ARM-dts-qcom-apq8064-Add-qfprom_physical-memory-reso.patch \
            file://0001-ARM-dts-ifc6410-add-audio-clock-and-regulator-nodes.patch \
            file://0003-ath6kl-force-enable-ht-cap-override.patch \
            file://0004-ARM-dts-qcom-ifc6410-add-Krait-CPU-clock-topology.patch \
            file://0005-ARM-dts-qcom-ifc6410-add-initial-CPU-OPP-table.patch \
            file://0006-ARM-dts-qcom-ifc6410-select-default-CPU-speed-bin.patch \
            file://0007-ARM-dts-qcom-ifc6410-add-CPU-thermal-cooling-maps.patch \
            file://firmware/ \
            "

do_configure:prepend() {
    # 1. Populate firmware in both source and out-of-tree build dirs
    mkdir -p ${S}/firmware
    mkdir -p ${B}/firmware
    if [ -d "${WORKDIR}/firmware" ]; then
        cp -rf ${WORKDIR}/firmware/* ${S}/firmware/
        cp -rf ${WORKDIR}/firmware/* ${B}/firmware/
    fi
}

do_configure:append() {
    # 2. Force merge ifc6410.cfg into .config
    if [ -f "${WORKDIR}/ifc6410.cfg" ]; then
        bbnote "Merging ifc6410.cfg into .config"
        cat ${WORKDIR}/ifc6410.cfg >> ${B}/.config
        oe_runmake -C ${S} O=${B} olddefconfig
    fi
}

# Set the root partition
# /dev/sda1 is for SATA and USB connected drives
# /dev/mmcblk0p1 is for sdard
# /dev/mmcblk2p13 is for emmc
QCOM_BOOTIMG_ROOTFS = "/dev/sda1"

# Supply the required cmdline parameters directly to linux-qcom-bootimg
# cgroup=1 is for v2
KERNEL_CMDLINE_EXTRA = "libata.force=1.5Gbps,noncq systemd.unit=multi-user.target systemd.unified_cgroup_hierarchy=1"
