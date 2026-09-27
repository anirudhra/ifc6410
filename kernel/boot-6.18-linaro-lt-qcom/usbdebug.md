# IFC6410 USB debugging notes

## Context

This note captures the observed behavior difference between a working 6.6 kernel and a non-working 6.18 kernel on the IFC6410 so the same investigation does not need to be repeated later.

### Working case: Linux 6.6 booted from USB HDD rootfs

Observed environment:

- Kernel: `Linux ifc6410 6.6.9-00205-g3565a579b978-dirty`
- Root filesystem: USB HDD on `/dev/sda1`
- USB mass storage bridge: `174c:55aa` ASMT ASM105x
- USB Ethernet adapter: `0bda:8153` Realtek RTL8153

Key runtime observations from the 6.6 log:

- The SCSI and USB subsystems initialize normally.
- `ci_hdrc.1` and `ci_hdrc.2` both probe successfully as EHCI host controllers.
- Bus 1 enumerates the ASM105x storage bridge as a high-speed USB device.
- The storage bridge binds to `uas`.
- The disk appears as `sda`, with `sda1` serving as the working root filesystem.
- Bus 2 independently enumerates the RTL8153 USB Ethernet adapter.
- `lsusb -t` shows one device under each root hub:
  - Bus 1, Port 1: Mass Storage, driver `uas`, 480M
  - Bus 2, Port 1: Vendor specific, driver `r8152`, 480M

Interpretation of the 6.6 case:

- USB host controller bring-up works.
- USB PHY and port signaling work well enough for device detect and enumeration.
- VBUS and/or board-level port power are functional.
- UAS, usb-storage, SCSI, and block-layer discovery are all functional.
- Booting rootfs from `/dev/sda1` is proven good in this kernel.

### Failing case: Linux 6.18 booted from eMMC rootfs

Observed environment:

- Kernel: `Linux ifc6410 6.18.44-g8a24e588aae7-dirty`
- Root filesystem: eMMC, because USB is not functional enough to boot from the HDD

Key runtime observations from the 6.18 log:

- The SCSI and USB subsystems initialize normally.
- `ci_hdrc.1` and `ci_hdrc.2` both still probe successfully as EHCI host controllers.
- USB root hubs for bus 1 and bus 2 are created successfully.
- No downstream USB device enumeration occurs afterward.
- There are no `usb 1-1` or `usb 2-1` connect/enumeration messages.
- There are no ASM105x or RTL8153 device-identification lines.
- There is no UAS or storage-device attach sequence leading to `sda`.
- `lsusb` is not installed in that rootfs, but that is not relevant to the core failure.

Interpretation of the 6.18 case:

- The ChipIdea/EHCI controller layer is alive.
- Clock, reset, and basic host-controller registration appear to work.
- The failure occurs below normal device enumeration.
- Since neither the storage bridge nor the Ethernet adapter enumerate, this is not a storage-specific or UAS-specific problem.
- The shared failure domain is the USB port / ULPI PHY / VBUS / low-level host-attach path.

## Main conclusion

The important conclusion is:

**6.18 does not fail in `uas`, `usb-storage`, SCSI, `/dev/sda1`, or rootfs mounting. It fails earlier, because attached USB devices never enumerate at all.**

This is supported by the side-by-side runtime behavior:

| Stage | 6.6 | 6.18 | Meaning |
|---|---|---|---|
| Controller probe | `ci_hdrc.1` and `.2` start | same | Host controller driver comes up in both |
| Root hubs | bus 1 and bus 2 created | same | EHCI host side is alive in both |
| Attached devices | ASM105x and RTL8153 enumerate | none enumerate | Port/PHY/power path is broken in 6.18 |
| Storage attach | `uas` binds and `sda` appears | impossible because no device exists | Storage stack is not the primary fault |

## Device-tree comparison context

A DTB comparison between the 6.6 and 6.18 builds showed that the same overall APQ8064 USB structure is still present:

- `usb@12500000` remains `qcom,ci-hdrc` with `drmode = "otg"`
- `usb@12520000` remains `qcom,ci-hdrc` with `drmode = "host"`
- `usb@12530000` remains `qcom,ci-hdrc` with `drmode = "host"`
- The controllers still use ULPI PHYs.
- Clocking, reset linkage, assigned clock rates, and PHY references are still represented.
- The associated HS PHY nodes remain present with supply references.

Interpretation:

- The 6.18 DT is not obviously missing the entire USB controller nodes.
- The repeated dependency-cycle messages are worth noting, but they do not by themselves prove the cause of the failure.
- The best current hypothesis remains that 6.18 regresses the ULPI PHY, port-power, VBUS, or related low-level host-attach behavior.

## Practical debugging guidance

### What this likely is not

Based on current evidence, avoid spending time first on these areas:

- `uas`
- `usb-storage`
- SCSI scanning
- partition detection
- `/dev/sda1`
- rootfs mount parameters
- ASM105x bridge quirks only
- Ethernet-adapter-specific quirks only

Reason: both the storage bridge and the Ethernet adapter disappear together in 6.18, before normal enumeration completes.

### What this most likely is

Focus first on:

- USB HS PHY initialization
- ULPI interaction/regression
- VBUS drive or port-power enable behavior
- host-port connect detection
- board-specific DT property behavior change
- CI HDRC / ChipIdea behavior change between 6.6 and 6.18

## Best next checks to rerun later

### 1. Boot 6.18 with devices already connected

Connect the USB HDD and the USB Ethernet adapter before booting, then boot 6.18 from eMMC.

### 2. Force runtime PM to stay on for the root hubs

Run:

```sh
for p in /sys/bus/usb/devices/usb*/power/control; do
    echo on > "$p"
done

dmesg -w
```

Then physically unplug and replug the USB HDD once and watch the log.

Interpretation:

- If new `usb 1-1` or `usb 2-1` messages appear, runtime PM may be involved.
- If there is still complete silence, that strongly points toward VBUS, ULPI PHY, or low-level port state not being established.

### 3. Dump live devicetree properties from the running 6.18 system

Run:

```sh
for n in /sys/firmware/devicetree/base/soc/usb@12520000 \
         /sys/firmware/devicetree/base/soc/usb@12530000; do
    echo "===== $n ====="
    find "$n" -maxdepth 3 -type f -printf '%P: ' \
      -exec sh -c 'tr -d "\000" < "$1"; echo' sh {} \;
done
```

Goal:

- Reconfirm the live runtime DT properties for the two host controllers.
- Check whether a board-required property present in the working setup is absent or handled differently in 6.18.

### 4. Compare 6.6 and 6.18 around the point where devices should appear

Key question to keep in mind:

- In 6.6, what exact event sequence happens between root-hub registration and the first `usb 1-1` / `usb 2-1` messages?
- In 6.18, what low-level step never happens?

## Short future-reference version

When returning to this later, remember this one-line summary:

**6.6 proves the IFC6410 can boot from a USB HDD on `/dev/sda1` through an ASM105x bridge using `uas`, while 6.18 still brings up the CI HDRC host controllers but never enumerates any downstream USB devices, so the bug is almost certainly in the port/PHY/VBUS/ULPI layer rather than storage or rootfs handling.**
