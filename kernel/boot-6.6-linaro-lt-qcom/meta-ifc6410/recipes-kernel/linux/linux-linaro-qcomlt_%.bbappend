FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
file://devfreq.cfg \
file://0001-ARM-dts-qcom-apq8064-Add-qfprom_physical-memory-reso.patch \
file://0001-ARM-dts-ifc6410-add-audio-and-bluetooth.patch \
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
# 2. Force merge devfreq.cfg into .config
if [ -f "${WORKDIR}/devfreq.cfg" ]; then
    bbnote "Merging devfreq.cfg into .config"
    cat ${WORKDIR}/devfreq.cfg >> ${B}/.config
    oe_runmake -C ${S} O=${B} olddefconfig
fi
}
