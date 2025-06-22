# QCOM IFC6410 (APQ8064) firmware

The qcom-fw-image directory archives QCOM IFC6410 (with APQ8064 SoC) firmware blob image for preservation. Typically, this image is flashed to /dev/mmcblk0p15 partition (a.k.a "cache" in Android world) once and not touched.

A more reliable way is to copy the relevant firmware blobs to rootfs /lib/firmware (or /usr/lib/firmware) directory instead of mounting the partition everytime. Place the contents of the archive locally to /lib/firmware (or /usr/lib/firmware depending on the distro).
