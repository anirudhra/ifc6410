# IFC6410 Linux 6.18 Patch Plan

**Date:** 2026-09-26  
**Purpose:** Resume point for the Poky 6.0 / Linux 6.18 IFC6410 migration.  
**Reference tree:** legacy 6.6 patch directory at `/mnt/pve-sata-ssd/ssd-data/backup/ifc6410/github/poky/meta-ifc6410/recipes-kernel/linux/files`. [cite:1211][cite:1212]

**Active 6.18 kernel tree:** `/mnt/pve-sata-ssd/ssd-data/backup/ifc6410/github/poky6.0/build/qcom-armv7a/tmp/work-shared/ifc6410/kernel-source`. [cite:1212]

## Working rules

- Legacy patch filenames and numeric prefixes are **not globally sequential**; never infer missing patches from numbering. [cite:1210]
- Review and apply changes in functional dependency order, not lexicographic filename order. [cite:1210]
- Terminal guidance should stay one command at a time, narrowly scoped, with manageable output. [cite:1210]
- Do not reintroduce legacy patches merely because they existed; retain confirmed board policy and independently verify generic fixes. [cite:1210]
- Temporary boot testing is preferred before permanent flashing. [cite:1211]

## Current kernel status

- The 6.18 kernel now boots Debian 12, so the earlier boot-blocking IOMMU/DMA problem is already resolved in the tested build. [cite:1211]
- USB remains unresolved: `ci_hdrc` port reset timeout `-110` persists. [cite:1211]
- Native SATA is intentionally not used; the active external root/storage test path is USB-to-SATA. [cite:1211]
- The current kernel tree is dirty: `arch/arm/tools/gen-mach-types` modified, `drivers/iommu/msm_iommu.c` modified, and untracked `firmware/`. [cite:1211]
- The modified `msm_iommu.c` likely explains why the old boot-blocking IOMMU issue is already resolved in the current 6.18 build. [cite:1211]

## Legacy inventory

```text
0001-ARM-dma-mapping-reset-DMA-ops-before-IOMMU-detach.patch
0001-ARM-dts-ifc6410-add-audio-clock-and-regulator-nodes.patch
0001-ARM-dts-qcom-apq8064-Add-qfprom_physical-memory-reso.patch
0002-iommu-msm-track-a-context-master-per-device-and-IOMM.patch
0003-ath6kl-force-enable-ht-cap-override.patch
0003-iommu-msm-use-the-IOMMU-device-for-page-table-allocation.patch
0004-ARM-dts-qcom-ifc6410-add-Krait-CPU-clock-topology.patch
0004-drm-msm-release-ARM-DMA-mapping-before-attaching-own.patch
0005-ARM-dts-qcom-ifc6410-add-initial-CPU-OPP-table.patch
0006-ARM-dts-qcom-ifc6410-select-default-CPU-speed-bin.patch
0007-ARM-dts-qcom-ifc6410-add-CPU-thermal-cooling-maps.patch
0008-ARM-dts-qcom-ifc6410-add-GPU-vddcx-regulator-supply.patch
```

## Planned DTS patches

## 1. APQ8064 HDMI QFPROM resource

**Legacy source:** `0001-ARM-dts-qcom-apq8064-Add-qfprom_physical-memory-reso.patch`. [cite:1210]

**Decision:** Port independently.

**Change:**

```dts
reg = <0x04a00000 0x2f0>,
      <0x00700000 0x6100>;
reg-names = "core_physical", "qfprom_physical";
```

**Scope:** HDMI only. It adds a second named MMIO range for the HDMI transmitter. This is **not** the QFPROM NVMEM provider for CPU speed-bin reading. The current APQ8064 common DTS already has a labeled `qfprom: efuse@700000` node with `compatible = "qcom,apq8064-qfprom", "qcom,qfprom"`. [cite:945]

## 2. IFC6410 Krait CPU clock topology

**Legacy source:** `0004-ARM-dts-qcom-ifc6410-add-Krait-CPU-clock-topology.patch`. [cite:1210]

**Decision:** Port.

**Evidence established:**

- Current IFC6410 DTS has no `kraitcc` node and no CPU `clocks` bindings. [cite:945]
- APQ8064 common DTS provides `acc0`, `acc1`, `acc2`, `acc3`, and `l2cc`. [cite:945]
- The 6.18 driver supports `qcom,krait-cc-v1` and explicitly handles up to four CPUs plus L2. [cite:945]

**Intended topology:**

```dts
kraitcc: clock-controller {
        compatible = "qcom,krait-cc-v1";
        #clock-cells = <1>;

        clocks = <&gcc PLL9>, <&gcc PLL10>,
                 <&gcc PLL16>, <&gcc PLL17>,
                 <&gcc PLL12>, <&acc0>,
                 <&acc1>, <&acc2>, <&acc3>, <&l2cc>;
        clock-names = "hfpll0", "hfpll1",
                      "hfpll2", "hfpll3",
                      "hfpll_l2", "acpu0_aux",
                      "acpu1_aux", "acpu2_aux",
                      "acpu3_aux", "acpu_l2_aux";
};
```

Then bind `CPU0` through `CPU3` to `<&kraitcc 0>` through `<&kraitcc 3>`. [cite:945]

## 3. Conservative CPU OPP table

**Legacy sources:** `0005-ARM-dts-qcom-ifc6410-add-initial-CPU-OPP-table.patch` and `0006-ARM-dts-qcom-ifc6410-select-default-CPU-speed-bin.patch`. [cite:1210]

**Decision:** Squash into one patch; port as a conservative initial policy.

**Dependencies:**

- Krait clock topology must land first. [cite:945]
- Existing APQ8064 QFPROM provider already exists. [cite:945]

**Retain:**

```dts
&qfprom {
        speedbin_efuse: speedbin@c0 {
                reg = <0xc0 0x8>;
        };
};
```

**OPP choices:**

- 391.5 MHz. [cite:945]
- 918 MHz. [cite:945]
- `opp-supported-hw = <0x1>`. [cite:945]
- `clock-latency-ns = <100000>`. [cite:945]
- `opp-shared`. [cite:945]

**Required correction:** use `compatible = "operating-points-v2-krait-cpu"`, not `operating-points-v2-kryo-cpu`. The binding supports both names, but Krait is the semantically correct one for APQ8064. [web:1215][web:1217]

**Limitation:** the initial table has no `opp-microvolt`; do not invent voltage data. It is a conservative frequency-only enablement table, not proven full DVFS. [web:1221]

## 4. CPU thermal cooling maps

**Legacy source:** `0007-ARM-dts-qcom-ifc6410-add-CPU-thermal-cooling-maps.patch`. [cite:1210]

**Decision:** Port provisionally as written.

**Reason:** all four TSENS zones reference `CPU0`, but that may be intentional because the platform may expose one shared cpufreq cooling device or policy while the hardware handles the internal multi-core topology. Do not rewrite CPU1 to CPU3 mappings merely because the source repeats `CPU0`. [cite:1263][web:1243][web:1246]

**Dependencies:**

- Krait topology. [cite:945]
- Working OPP/cpufreq policy. [cite:945]

**Runtime validation after boot:**

- Identify cpufreq policies.
- Identify cooling devices.
- Confirm thermal-zone bindings.
- Change the map only if runtime topology shows separately controllable policies that should be individually bound. [cite:1263]

## 5. GPU `vddcx` regulator

**Legacy source:** `0008-ARM-dts-qcom-ifc6410-add-GPU-vddcx-regulator-supply.patch`. [cite:1210]

**Decision:** Already ported and runtime validated.

**Change:**

```dts
&gpu {
        vddcx-supply = <&pm8921_s3>;
};
```

**Evidence:**

- `pm8921_s3` exists in current IFC6410 DTS. [cite:945]
- The prior vddcx dummy-regulator warning disappeared after this patch. [cite:1272]
- GPU devfreq/cooling was validated. [cite:1270]
- GPU `vdd` and GPU voltage corners remain intentionally unspecified. [cite:1272]

**Action:** do not duplicate it if it is already present in the active layer.

## 6. SDCC4 external clock

**Legacy source:** embedded in `0001-ARM-dts-ifc6410-add-audio-clock-and-regulator-nodes.patch`. [cite:1210]

**Decision:** Port as a separate patch.

**Change:**

```dts
&sdcc4_pwrseq {
        clocks = <&rpmcc RPM_XO_A2>;
        clock-names = "ext_clock";
};
```

**Purpose:** supplies the external SDCC4/WLAN clock path. [cite:945]

**Order:** before validating Wi-Fi and before the ath6kl HT workaround. [cite:945]

## 7. PM8921 power rails

**Legacy source:** embedded in `0001-ARM-dts-ifc6410-add-audio-clock-and-regulator-nodes.patch`. [cite:1210]

**Decision:** Port as one board-power-policy patch.

**Known-good legacy configuration:**

```dts
&pm8921_ncp {
        qcom,switch-mode-frequency = <1600000>;
        status = "okay";
};

&pm8921_s2 {
        regulator-min-microvolt = <1300000>;
        regulator-max-microvolt = <1300000>;
        qcom,switch-mode-frequency = <1600000>;
        regulator-always-on;
        regulator-boot-on;
        bias-pull-down;
};

&pm8921_s8 {
        regulator-min-microvolt = <2050000>;
        regulator-max-microvolt = <2050000>;
        qcom,switch-mode-frequency = <1600000>;
        regulator-always-on;
        regulator-boot-on;
        bias-pull-down;
};
```

**Rationale:**

- Current 6.18 IFC6410 DTS has no explicit `pm8921_s2`, `pm8921_s8`, or `pm8921_ncp` consumer phandles. [cite:945]
- That absence does **not** invalidate a known-good always-on board rail policy. [cite:945]
- These rails were reported as wired and operational in the working 6.6 configuration. [cite:945]
- Keep NCP, S2, and S8 together as board-level power policy. [cite:945]

## 8. Bluetooth MPP1 enable

**Legacy source:** embedded in `0001-ARM-dts-ifc6410-add-audio-clock-and-regulator-nodes.patch`. [cite:1210]

**Decision:** Port as a separate patch.

**Change:**

```dts
&pm8921_mpps {
        pinctrl-names = "default";
        pinctrl-0 = <&bt_en_pin>;

        bt_en_pin: bt-en-pin {
                pins = "mpp1";
                function = "digital";
                output-high;
                power-source = <PM8921_MPP_S4>;
        };
};
```

**Purpose:** drives Bluetooth enable through PM8921 MPP1. [cite:945]

## 9. ath6kl HT capability override

**Legacy source:** `0003-ath6kl-force-enable-ht-cap-override.patch`. [cite:1210]

**Decision:** Port as an intentional local firmware workaround.

**Change:** force `ATH6KL_FW_CAPABILITY_RSN_CAP_OVERRIDE` in `ath6kl_init_hw_params()` after firmware capability parsing and before return. Mainline ath6kl still gates HT on this firmware capability. [web:1174]

**Rationale:** the platform firmware is believed to report the capability incorrectly; this local override is required to enable the desired 802.11n HT behavior. [web:1174]

**Order:** after the SDCC4 external-clock patch; separate from all DTS power/clock patches. [cite:945]

## Excluded or already satisfied

### IOMMU / DMA / DRM series

```text
0001-ARM-dma-mapping-reset-DMA-ops-before-IOMMU-detach.patch
0002-iommu-msm-track-a-context-master-per-device-and-IOMM.patch
0003-iommu-msm-use-the-IOMMU-device-for-page-table-allocation.patch
0004-drm-msm-release-ARM-DMA-mapping-before-attaching-own.patch
```

**Decision:** do not create a duplicate new series now.

**Reason:** the current test kernel reaches Debian boot, unlike the earlier 6.18 image that failed during init. The active kernel tree also contains a local `drivers/iommu/msm_iommu.c` modification, which must be inspected before any conclusion about the exact implementation or upstream status. [cite:1211]

## Recommended final ordering

```text
1. ARM: dts: qcom: apq8064: add HDMI QFPROM resource
2. ARM: dts: qcom: ifc6410: add Krait CPU clock topology
3. ARM: dts: qcom: ifc6410: add conservative CPU OPP table
4. ARM: dts: qcom: ifc6410: add CPU thermal cooling maps
5. ARM: dts: qcom: ifc6410: configure PM8921 required power rails
6. ARM: dts: qcom: ifc6410: add SDCC4 external clock
7. ARM: dts: qcom: ifc6410: enable Bluetooth through MPP1
8. ath6kl: force RSN capability override for IFC6410 HT
```

Exclude the GPU patch from this list **if** its existing validated patch is already in `SRC_URI`; otherwise insert it after patch 4. [cite:1272]

## Resume point

First inspect the existing local IOMMU change—not the whole source tree—and determine whether it is the active boot-enabling fix:

```sh
git -C "$K" diff -- drivers/iommu/msm_iommu.c
```

That should be the first command to run when resuming. [cite:1210]
