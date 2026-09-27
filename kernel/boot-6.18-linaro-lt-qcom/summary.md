# IFC6410 USB 6.18 Debug Summary

## Scope

This note summarizes the USB host debugging performed on the Inforce IFC6410 (Qualcomm APQ8064) while migrating the board from the older known-good 6.6-based setup to a Yocto 6.0 / Linux 6.18.44 kernel. The central symptom is repeated USB host-port reset timeout `-110` during enumeration on the Qualcomm ChipIdea/MSM USB host path.[cite:945][web:995]

## Initial symptom

The board boots Linux 6.18.44 and initializes the Qualcomm USB host controllers, but attached devices on the Type-A host ports fail to enumerate. The recurring kernel messages are `ci_hdrc ... port 1 reset error -110`, followed by `Cannot enable` and `unable to enumerate USB device`, which indicate timeout during host-side USB port reset/enumeration.[cite:945][web:826]

A controlled later test booted from the eMMC Debian 12 root filesystem on `mmcblk2p13` instead of USB storage and still reproduced the same USB reset failure, showing the issue is not dependent on booting root from a USB enclosure.[cite:945]

## Device tree observations

Runtime DT inspection on the board showed both host PHY nodes under `/soc/usb@12520000/ulpi/phy` and `/soc/usb@12530000/ulpi/phy` present with compatible string `qcom,usb-hs-phy-apq8064` and supply references for `v1p8-supply` and `v3p3-supply`. Those supply properties are required by the Qualcomm USB HS PHY binding.[web:919][web:921]

Source inspection of `qcom-apq8064-ifc6410.dts` showed the board DTS enables:

- `&usb1` as OTG.
- `&usb3` as host.
- `&usb4` as host.
- `&usb_hs3_phy` and `&usb_hs4_phy` with `v3p3-supply = <&pm8921_l3>` and `v1p8-supply = <&pm8921_l23>`.

The common `qcom-apq8064.dtsi` defines `usb1`, `usb3`, and `usb4` as `qcom,ci-hdrc` controllers with their own clocks, resets, PHY links, and ULPI PHY subnodes using the APQ8064-compatible Qualcomm HS PHY. That topology appeared internally consistent and did not reveal an obvious missing DT property.[web:975][web:976]

## Regulator and power observations

Regulator inspection on the board showed the relevant PHY rails enabled: `l3` at 3.3 V and `l23` at 1.7 V. This matched the active PHY supply assignments for the two host PHYs in the board DTS.[cite:945]

A `usb-switch` regulator was visible in sysfs and was disabled with zero users, but subsequent source inspection found no IFC6410 DTS node or host-controller binding using a literal `usb-switch` regulator reference. That hypothesis was therefore discarded, and no `vbus-supply` DT change was made.[cite:945]

## Driver observations

The current kernel clearly includes the Qualcomm MSM HSUSB glue layer. The running board binds the USB platform devices to `msm_hsusb`, and the build tree contains `ci_hdrc_msm.o`, which corresponds to `CONFIG_USB_CHIPIDEA_MSM`.[web:995][cite:945]

Both the stock-resolved and IFC6410-resolved 6.18 kernel configurations contained the core host-side requirements:

- `CONFIG_USB_CHIPIDEA=y`
- `CONFIG_USB_CHIPIDEA_MSM=y`
- `CONFIG_SCSI=y`
- `CONFIG_BLK_DEV_SD=y`
- `CONFIG_EXT4_FS=y`

The IFC6410-specific resolved config additionally enabled `CONFIG_USB_STORAGE=y`, `CONFIG_ATH6KL=y`, and built-in DRM/MSM, but the MSM ChipIdea host glue was present in both cases.[cite:945][web:990][web:995]

## Controlled experiment: remove ifc6410.cfg

A temporary change was made in `meta-ifc6410/recipes-kernel/linux/linux-qcom_%.bbappend` to remove `file://ifc6410.cfg` from `SRC_URI`, while leaving the built-in firmware staging and IOMMU patch `0002-iommu-msm-track-a-context-master-per-device-and-IOMM.patch` enabled. This created a clean test of stock 6.18 configuration plus the minimum IOMMU change already considered necessary for boot stability.[cite:945]

The resulting kernel booted successfully from the Debian 12 eMMC root filesystem on `mmcblk2p13`, which avoided any dependency on USB mass-storage boot. Despite removing `ifc6410.cfg`, the same USB host reset timeout still occurred on `ci_hdrc.1`, with repeated `port 1 reset error -110`, `Cannot enable`, and `unable to enumerate USB device` messages.[cite:945][web:826]

This experiment ruled out `ifc6410.cfg` as the cause of the USB enumeration failure. It also ruled out the USB-related kernel options added by that fragment as the proximate cause of the observed host reset timeout.[cite:945]

## Other observations from boot logs

During the 6.18 boots, the OTG controller `ci_hdrc.0` also logged `timeout waiting for 00000800 in OTGSC`. That warning was on the separate OTG controller and was not proven to be the direct cause of the host-port enumeration failure on `ci_hdrc.1`.[cite:945]

The system also showed unrelated probe issues during boot, including PCIe and SPI pin conflicts and dummy-regulator warnings on SATA. Those were not the focus of this USB investigation and were not tied to the reproduced USB reset failure.[cite:945]

## External research results

A targeted search across Linux USB/Qualcomm discussions, kernel archives, and 6.18-related reports did not find a documented, confirmed regression specifically identifying APQ8064, IFC6410, `qcom,ci-hdrc`, or `msm_hsusb` as broken on Linux 6.18. Reports do exist for USB regressions on other older ARM boards in 6.18, but they involve different hardware and do not establish the same root cause for APQ8064’s USB 2.0 ChipIdea/ULPI path.[web:1047][web:1049][web:1050]

Therefore, the current working assessment is that this may be an unreported regression, a board-specific timing/electrical sensitivity exposed by 6.18, or a difference between the known-good 6.6 tree and the 6.18 `linux-qcom` path in the Qualcomm ChipIdea/MSM glue, Qualcomm HS PHY driver, or closely related DTS integration.[cite:945]

## Current conclusions

The following possibilities were effectively ruled out:

- Missing `msm_hsusb` driver support.[web:995][cite:945]
- A missing obvious USB host/PHY DTS enablement for `usb3` and `usb4`.[web:975][web:976]
- Absent PHY supply properties on the host PHY nodes.[web:919][web:921]
- The `ifc6410.cfg` kernel fragment as the cause of the USB reset failure.[cite:945]

The most plausible remaining areas are:

- Regression or behavioural change in `drivers/usb/chipidea/`.
- Regression or behavioural change in `drivers/phy/qualcomm/phy-qcom-usb-hs.c`.
- A 6.6 versus 6.18 DTS or driver interaction difference specific to APQ8064 host USB.
- A board-level timing or VBUS/electrical issue tolerated by 6.6 but not by 6.18.[cite:945][web:995]

## Recommended next step when resuming

The highest-value next investigation is a targeted source comparison between the known-good 6.6 tree and the 6.18 tree for:

- `drivers/usb/chipidea/`
- `drivers/phy/qualcomm/phy-qcom-usb-hs.c`
- `arch/arm/boot/dts/qcom/qcom-apq8064.dtsi`
- `arch/arm/boot/dts/qcom/qcom-apq8064-ifc6410.dts`

That comparison should identify whether a narrow revert, backport, or targeted instrumentation patch is the most promising next move.[cite:945]
