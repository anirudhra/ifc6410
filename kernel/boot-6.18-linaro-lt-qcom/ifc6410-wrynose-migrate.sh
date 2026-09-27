#!/usr/bin/env bash
set -Eeuo pipefail
shopt -s nullglob

# IFC6410: Yocto 5.0 (Scarthgap) -> 6.0 (Wrynose), Linux 6.18 migration harness.
# The default action is help. No build or source tree is changed unless a
# mutating subcommand is explicitly selected.

BASE=${BASE:-/mnt/pve-sata-ssd/ssd-data/backup/ifc6410/github}
OLD=${OLD:-$BASE/poky}
NEW=${NEW:-$BASE/poky6.0}
OLD_BUILD=${OLD_BUILD:-$OLD/build/qcom-armv7a}
BUILD_DIR=${BUILD_DIR:-$NEW/build/qcom-armv7a}
BACKUP_ROOT=${BACKUP_ROOT:-$BASE/migration-backups}
IFC_LAYER_SRC=${IFC_LAYER_SRC:-}

YOCTO_RELEASE=${YOCTO_RELEASE:-yocto-6.0.3}
OECORE_URL=${OECORE_URL:-https://git.openembedded.org/openembedded-core}
BITBAKE_URL=${BITBAKE_URL:-https://git.openembedded.org/bitbake}
META_YOCTO_URL=${META_YOCTO_URL:-https://git.yoctoproject.org/meta-yocto}
META_QCOM_URL=${META_QCOM_URL:-https://github.com/qualcomm-linux/meta-qcom.git}
META_MIXINS_URL=${META_MIXINS_URL:-https://git.yoctoproject.org/meta-lts-mixins}
META_QCOM_REF=${META_QCOM_REF:-wrynose}
META_MIXINS_REF=${META_MIXINS_REF:-wrynose/linux-firmware}

CORE=$NEW/openembedded-core
BITBAKE=$NEW/bitbake
META_YOCTO=$NEW/meta-yocto
META_QCOM=$NEW/meta-qcom
META_MIXINS=$NEW/meta-lts-mixins
IFC_LAYER_DST=$NEW/meta-ifc6410
STATE_DIR=$NEW/.ifc6410-migration-state
LOG_DIR=$NEW/logs

STAMP=$(date -u +%Y%m%dT%H%M%SZ)

say()  { printf '\n==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

on_error() {
    local rc=$?
    printf '\nERROR: command failed at line %s (exit %s): %s\n' \
        "${BASH_LINENO[0]:-?}" "$rc" "${BASH_COMMAND:-?}" >&2
    exit "$rc"
}
trap on_error ERR

usage() {
    cat <<EOF
Usage: $(basename "$0") COMMAND

Safe phased commands:
  preflight       Validate paths, tools, free space, refs, and locate meta-ifc6410
  archive         Capture old configs, Git state/bundles, layer tarball, and BitBake metadata only
  prepare         Run archive + clone Wrynose + create stock build configuration
  stock-build     Build unmodified linux-qcom 6.18; creates a success checkpoint
  stage-layer     Copy and migrate meta-ifc6410 to a config/firmware-only Wrynose layer
  custom-build    Build 6.18 with the staged layer, but with all source patches still disabled
  status          Display revisions, checkpoints, configured layers, and key kernel variables
  all             Run prepare, stock-build, stage-layer, and custom-build in order
  help            Show this help

Environment overrides:
  BASE=$BASE
  OLD=$OLD
  NEW=$NEW
  OLD_BUILD=$OLD_BUILD
  BUILD_DIR=$BUILD_DIR
  IFC_LAYER_SRC=/absolute/path/to/meta-ifc6410
  YOCTO_RELEASE=$YOCTO_RELEASE
  MIN_FREE_GIB=80                 # preflight warning threshold
  ALLOW_SKIP_STOCK=1             # permit stage-layer without the stock-build checkpoint
  FORCE_STAGE=1                  # replace an existing staged meta-ifc6410 copy

Recommended sequence (prepare already performs archive):
  $(basename "$0") preflight
  $(basename "$0") prepare
  $(basename "$0") stock-build
  $(basename "$0") stage-layer
  $(basename "$0") custom-build

The script deliberately does NOT enable or forward-port the old .patch files.
That is a later, one-patch-at-a-time phase after both baseline builds pass.
EOF
}

require_cmds() {
    local missing=0 cmd
    for cmd in bash git tar gzip sha256sum sed awk grep find df python3 curl; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            printf 'Missing required command: %s\n' "$cmd" >&2
            missing=1
        fi
    done
    (( missing == 0 )) || die "Install the missing host tools first."
}

resolve_ifc_layer() {
    if [[ -n "$IFC_LAYER_SRC" ]]; then
        [[ -f "$IFC_LAYER_SRC/conf/layer.conf" ]] || \
            die "IFC_LAYER_SRC is not a layer: $IFC_LAYER_SRC"
        readlink -f "$IFC_LAYER_SRC"
        return
    fi

    local candidates=() p
    for p in \
        "$OLD/meta-ifc6410" \
        "$BASE/ifc6410/kernel/boot-6.6-linaro-lt-qcom/meta-ifc6410"; do
        [[ -f "$p/conf/layer.conf" ]] && candidates+=("$(readlink -f "$p")")
    done

    while IFS= read -r p; do
        [[ "$p" == "$NEW"/* ]] && continue
        candidates+=("$(dirname "$(dirname "$p")")")
    done < <(find "$BASE" -maxdepth 8 -type f \
        -path '*/meta-ifc6410/conf/layer.conf' 2>/dev/null | sort -u)

    mapfile -t candidates < <(printf '%s\n' "${candidates[@]}" | awk 'NF && !seen[$0]++')
    if (( ${#candidates[@]} == 0 )); then
        die "Could not find meta-ifc6410. Set IFC_LAYER_SRC=/absolute/path/to/meta-ifc6410"
    elif (( ${#candidates[@]} > 1 )); then
        printf 'Multiple meta-ifc6410 layers found:\n' >&2
        printf '  %s\n' "${candidates[@]}" >&2
        die "Set IFC_LAYER_SRC explicitly."
    fi
    printf '%s\n' "${candidates[0]}"
}

check_remote_ref() {
    local url=$1 ref=$2
    git ls-remote --exit-code "$url" \
        "refs/heads/$ref" "refs/tags/$ref" "refs/tags/$ref^{}" >/dev/null || \
        die "Remote ref not found: $url :: $ref"
}

preflight() {
    require_cmds
    [[ $EUID -ne 0 ]] || die "Run this as your normal build user, not root."
    [[ -d "$OLD" ]] || die "Existing Scarthgap tree not found: $OLD"
    mkdir -p "$BASE"

    local src free_kib free_gib min_free=${MIN_FREE_GIB:-80}
    src=$(resolve_ifc_layer)
    free_kib=$(df -Pk "$BASE" | awk 'NR==2 {print $4}')
    free_gib=$(( free_kib / 1024 / 1024 ))

    say "Resolved paths"
    printf 'Old tree:       %s\n' "$OLD"
    printf 'Old build:      %s\n' "$OLD_BUILD"
    printf 'New workspace:  %s\n' "$NEW"
    printf 'IFC layer:      %s\n' "$src"
    printf 'Free space:     %s GiB\n' "$free_gib"
    (( free_gib >= min_free )) || \
        warn "Only ${free_gib} GiB is free; ${min_free} GiB or more is recommended."

    say "Checking upstream refs"
    check_remote_ref "$OECORE_URL" "$YOCTO_RELEASE"
    check_remote_ref "$BITBAKE_URL" "$YOCTO_RELEASE"
    check_remote_ref "$META_YOCTO_URL" "$YOCTO_RELEASE"
    check_remote_ref "$META_QCOM_URL" "$META_QCOM_REF"
    check_remote_ref "$META_MIXINS_URL" "$META_MIXINS_REF"

    say "Host"
    uname -a
    [[ -r /etc/os-release ]] && cat /etc/os-release
    say "Preflight passed"
}

snapshot_git_repo() {
    local repo=$1 out=$2 label
    label=$(printf '%s' "${repo#$BASE/}" | sed 's#[^A-Za-z0-9._-]#_#g')
    [[ -n "$label" ]] || label=root
    mkdir -p "$out/$label"

    git -C "$repo" rev-parse --show-toplevel > "$out/$label/toplevel.txt"
    git -C "$repo" status --short --branch > "$out/$label/status.txt"
    git -C "$repo" remote -v > "$out/$label/remotes.txt" || true
    git -C "$repo" branch -avv > "$out/$label/branches.txt" || true
    git -C "$repo" tag --points-at HEAD > "$out/$label/head-tags.txt" || true
    git -C "$repo" log -20 --decorate --date=iso --pretty=fuller > "$out/$label/log.txt"
    git -C "$repo" diff --binary > "$out/$label/worktree.patch"
    git -C "$repo" diff --cached --binary > "$out/$label/index.patch"
    git -C "$repo" ls-files --others --exclude-standard > "$out/$label/untracked.txt"
    git -C "$repo" bundle create "$out/$label/repository.bundle" --all || \
        warn "Could not make Git bundle for $repo"
}

archive_old() {
    preflight
    local src backup repo top
    src=$(resolve_ifc_layer)
    backup=$BACKUP_ROOT/scarthgap-$STAMP
    mkdir -p "$backup"/{git,config,metadata}

    say "Archiving configuration and custom layer to $backup"
    {
        printf 'created_utc=%s\n' "$STAMP"
        printf 'base=%s\nold=%s\nold_build=%s\nnew=%s\n' "$BASE" "$OLD" "$OLD_BUILD" "$NEW"
        printf 'ifc_layer_src=%s\n' "$src"
        uname -a
        [[ -r /etc/os-release ]] && cat /etc/os-release
    } > "$backup/metadata/provenance.txt"

    tar -C "$(dirname "$src")" -czf "$backup/config/meta-ifc6410.tar.gz" \
        "$(basename "$src")"

    if [[ -d "$OLD_BUILD/conf" ]]; then
        tar -C "$OLD_BUILD" -czf "$backup/config/old-build-conf.tar.gz" conf
    else
        warn "Old build conf not found: $OLD_BUILD/conf"
    fi

    if git -C "$OLD" rev-parse --show-toplevel >/dev/null 2>&1; then
        top=$(git -C "$OLD" rev-parse --show-toplevel)
        snapshot_git_repo "$top" "$backup/git"
    fi
    if git -C "$src" rev-parse --show-toplevel >/dev/null 2>&1; then
        top=$(git -C "$src" rev-parse --show-toplevel)
        snapshot_git_repo "$top" "$backup/git"
    fi

    find "$OLD" \
        \( -path '*/tmp' -o -path '*/sstate-cache' -o -path '*/downloads' \) -prune -o \
        -type d -name .git -print 2>/dev/null |
    while IFS= read -r repo; do
        top=${repo%/.git}
        snapshot_git_repo "$top" "$backup/git"
    done

    if [[ -f "$OLD/oe-init-build-env" && -d "$OLD_BUILD/conf" ]]; then
        say "Capturing old BitBake metadata (read-only)"
        (
            set +u
            source "$OLD/oe-init-build-env" "$OLD_BUILD" >/dev/null
            set -u
            bitbake-layers show-layers > "$backup/metadata/show-layers.txt"
            bitbake-layers show-appends > "$backup/metadata/show-appends.txt"
            bitbake -e virtual/kernel | gzip -9 > "$backup/metadata/virtual-kernel.env.gz"
        ) || warn "Old BitBake metadata capture failed; filesystem and Git archives still exist."
    else
        warn "Old environment/build directory not detected; skipping BitBake metadata capture."
    fi

    find "$backup" -type f ! -name SHA256SUMS -print0 | sort -z |
        xargs -0 sha256sum > "$backup/SHA256SUMS"
    printf '%s\n' "$backup" > "$BACKUP_ROOT/LATEST"
    say "Archive complete"
    printf 'Backup: %s\n' "$backup"
    printf 'Verify: (cd %q && sha256sum -c SHA256SUMS)\n' "$backup"
}

clone_ref() {
    local url=$1 ref=$2 dest=$3
    if [[ -e "$dest" ]]; then
        [[ -d "$dest/.git" ]] || die "Path exists but is not a Git checkout: $dest"
        [[ -z "$(git -C "$dest" status --porcelain)" ]] || \
            die "Existing checkout is dirty: $dest"
        say "Keeping existing checkout: $dest"
        return
    fi
    say "Cloning $url ($ref)"
    git clone --branch "$ref" --single-branch "$url" "$dest"
}

write_local_conf() {
    local machine=$1 conf=$BUILD_DIR/conf/local.conf tmp
    [[ -f "$conf" ]] || die "Missing local.conf: $conf"
    tmp=$(mktemp)
    awk '
        $0 == "# BEGIN IFC6410 MIGRATION MANAGED BLOCK" {skip=1; next}
        $0 == "# END IFC6410 MIGRATION MANAGED BLOCK"   {skip=0; next}
        !skip {print}
    ' "$conf" > "$tmp"
    cat >> "$tmp" <<EOF

# BEGIN IFC6410 MIGRATION MANAGED BLOCK
MACHINE = "$machine"
DISTRO = "poky"
# The retained IFC6410 command line contains systemd-specific arguments.
INIT_MANAGER = "systemd"

PREFERRED_PROVIDER_virtual/kernel = "linux-qcom"
PREFERRED_VERSION_linux-qcom = "6.18%"

DL_DIR = "$NEW/downloads"
SSTATE_DIR = "$NEW/sstate-cache"

INITRAMFS_IMAGE = ""
INITRAMFS_IMAGE_BUNDLE = "0"
# END IFC6410 MIGRATION MANAGED BLOCK
EOF
    mv "$tmp" "$conf"
}

source_new_env() {
    [[ -f "$CORE/oe-init-build-env" ]] || die "Run prepare first."
    set +u
    source "$CORE/oe-init-build-env" "$BUILD_DIR" >/dev/null
    set -u
}

layer_is_enabled() {
    local layer=$1
    bitbake-layers show-layers 2>/dev/null | grep -Fq "$(readlink -f "$layer")"
}

add_layer_once() {
    local layer=$1
    layer_is_enabled "$layer" || bitbake-layers add-layer "$layer"
}

record_revisions() {
    local out=$NEW/revisions.txt repo
    : > "$out"
    for repo in "$CORE" "$BITBAKE" "$META_YOCTO" "$META_QCOM" "$META_MIXINS"; do
        printf '%-22s %s  %s\n' \
            "$(basename "$repo")" \
            "$(git -C "$repo" rev-parse HEAD)" \
            "$(git -C "$repo" describe --always --tags --dirty)" >> "$out"
    done
    cat "$out"
}

prepare() {
    archive_old
    mkdir -p "$NEW" "$STATE_DIR" "$LOG_DIR"

    clone_ref "$OECORE_URL" "$YOCTO_RELEASE" "$CORE"
    clone_ref "$BITBAKE_URL" "$YOCTO_RELEASE" "$BITBAKE"
    clone_ref "$META_YOCTO_URL" "$YOCTO_RELEASE" "$META_YOCTO"
    clone_ref "$META_QCOM_URL" "$META_QCOM_REF" "$META_QCOM"
    clone_ref "$META_MIXINS_URL" "$META_MIXINS_REF" "$META_MIXINS"

    say "Recording immutable revisions"
    record_revisions

    say "Creating the stock qcom-armv7a build configuration"
    source_new_env
    add_layer_once "$META_YOCTO/meta-poky"
    add_layer_once "$META_MIXINS"
    add_layer_once "$META_QCOM"
    write_local_conf qcom-armv7a

    bitbake-layers show-layers | tee "$LOG_DIR/layers-stock.txt"
    bitbake-layers show-recipes linux-qcom | tee "$LOG_DIR/linux-qcom-recipes.txt"
    bitbake -e virtual/kernel |
        grep -E '^(PN|PV|S|B|SRCREV|KBUILD_DEFCONFIG|KERNEL_DEVICETREE|PREFERRED_PROVIDER_virtual/kernel)=' |
        tee "$LOG_DIR/kernel-selection-stock.txt"

    touch "$STATE_DIR/prepared"
    say "Preparation complete; no compile has been started"
    printf 'Next: %s stock-build\n' "$0"
}

stock_build() {
    [[ -f "$STATE_DIR/prepared" ]] || die "Run prepare first."
    mkdir -p "$LOG_DIR" "$STATE_DIR"
    source_new_env
    write_local_conf qcom-armv7a

    say "Checking that the custom layer is not enabled"
    if [[ -d "$IFC_LAYER_DST" ]] && layer_is_enabled "$IFC_LAYER_DST"; then
        die "meta-ifc6410 is enabled; remove it before the stock baseline build."
    fi

    say "Fetching and patching stock linux-qcom 6.18"
    bitbake -c fetch virtual/kernel 2>&1 | tee "$LOG_DIR/stock-fetch.log"
    bitbake -c patch virtual/kernel 2>&1 | tee "$LOG_DIR/stock-patch.log"

    say "Building stock linux-qcom 6.18"
    bitbake virtual/kernel 2>&1 | tee "$LOG_DIR/stock-kernel-build.log"

    find "$BUILD_DIR/tmp/deploy/images/qcom-armv7a" -maxdepth 1 -type f \
        \( -name 'zImage*' -o -name '*ifc6410*.dtb' -o -name 'boot-*.img' -o -name 'modules-*.tgz' \) \
        -printf '%f\n' | sort | tee "$LOG_DIR/stock-artifacts.txt"

    touch "$STATE_DIR/stock-kernel.ok"
    say "Stock kernel checkpoint passed"
}

init_layer_git() {
    local layer=$1
    if [[ ! -d "$layer/.git" ]]; then
        git -C "$layer" init -b wrynose-linux-6.18
        git -C "$layer" config user.name "IFC6410 migration"
        git -C "$layer" config user.email "ifc6410-migration@localhost"
        git -C "$layer" add -A
        git -C "$layer" commit -m "meta-ifc6410: import Scarthgap 6.6 baseline"
    fi
}

stage_layer() {
    [[ -f "$STATE_DIR/stock-kernel.ok" || ${ALLOW_SKIP_STOCK:-0} == 1 ]] || \
        die "Run stock-build first, or deliberately set ALLOW_SKIP_STOCK=1."

    local src old_append new_append migration_dir
    src=$(resolve_ifc_layer)
    old_append=$IFC_LAYER_DST/recipes-kernel/linux/linux-linaro-qcomlt_%.bbappend
    new_append=$IFC_LAYER_DST/recipes-kernel/linux/linux-qcom_%.bbappend
    migration_dir=$IFC_LAYER_DST/migration-scarthgap-reference

    if [[ -e "$IFC_LAYER_DST" ]]; then
        [[ ${FORCE_STAGE:-0} == 1 ]] || \
            die "$IFC_LAYER_DST exists. Set FORCE_STAGE=1 to replace it."
        rm -rf -- "$IFC_LAYER_DST"
    fi

    say "Copying custom layer without modifying the old source"
    mkdir -p "$IFC_LAYER_DST"
    tar -C "$src" --exclude='./.git' -cf - . | tar -C "$IFC_LAYER_DST" -xf -
    init_layer_git "$IFC_LAYER_DST"

    mkdir -p "$migration_dir"
    [[ -f "$old_append" ]] || die "Expected old append not found: $old_append"
    cp -a "$old_append" "$migration_dir/linux-linaro-qcomlt_%.bbappend.scarthgap"
    if [[ -f "$IFC_LAYER_DST/conf/machine/qcom-armv7a.conf" ]]; then
        mv "$IFC_LAYER_DST/conf/machine/qcom-armv7a.conf" \
           "$migration_dir/qcom-armv7a.conf.scarthgap"
    fi
    rm -f "$old_append"

    sed -i -E \
        's/^(LAYERSERIES_COMPAT_meta-ifc6410[[:space:]]*=[[:space:]]*)"[^"]*"/\1"wrynose"/' \
        "$IFC_LAYER_DST/conf/layer.conf"

    cat > "$IFC_LAYER_DST/conf/machine/ifc6410.conf" <<'EOF'
#@TYPE: Machine
#@NAME: Inforce IFC6410
#@DESCRIPTION: IFC6410 specialization of meta-qcom qcom-armv7a

require conf/machine/qcom-armv7a.conf

MACHINEOVERRIDES =. "ifc6410:"

PREFERRED_PROVIDER_virtual/kernel = "linux-qcom"
PREFERRED_VERSION_linux-qcom = "6.18%"

# Build only this board's DTB in the board-specific machine.
KERNEL_DEVICETREE = "qcom/qcom-apq8064-ifc6410.dtb"

QCOM_BOOTIMG_ROOTFS = "/dev/sda1"
KERNEL_CMDLINE_EXTRA:append = " libata.force=1.5Gbps,noncq systemd.unit=multi-user.target systemd.unified_cgroup_hierarchy=1"
EOF

    cat > "$new_append" <<'EOF'
# IFC6410 Wrynose migration baseline: config and built-in firmware only.
# Source patches remain intentionally disabled until the clean 6.18 build passes.

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " \
    file://ifc6410.cfg \
    file://firmware/ \
"

do_configure:prepend() {
    install -d ${S}/firmware ${B}/firmware
    if [ -d "${UNPACKDIR}/firmware" ]; then
        cp -a "${UNPACKDIR}/firmware/." "${S}/firmware/"
        cp -a "${UNPACKDIR}/firmware/." "${B}/firmware/"
    fi
}
EOF

    cat > "$IFC_LAYER_DST/PATCH-MIGRATION-ORDER.txt" <<'EOF'
Patches are deliberately not in SRC_URI yet. Test and forward-port one at a time:

1. 0001-ARM-dts-qcom-apq8064-Add-qfprom_physical-memory-reso.patch
2. 0001-ARM-dts-ifc6410-add-audio-clock-and-regulator-nodes.patch
3. 0003-ath6kl-force-enable-ht-cap-override.patch
4. 0004-ARM-dts-qcom-ifc6410-add-Krait-CPU-clock-topology.patch
5. 0005-ARM-dts-qcom-ifc6410-add-initial-CPU-OPP-table.patch
6. 0006-ARM-dts-qcom-ifc6410-select-default-CPU-speed-bin.patch
7. 0007-ARM-dts-qcom-ifc6410-add-CPU-thermal-cooling-maps.patch
8. 0001-ARM-dma-mapping-reset-DMA-ops-before-IOMMU-detach.patch
9. 0002-iommu-msm-track-a-context-master-per-device-and-IOMM.patch
10. 0003-iommu-msm-use-the-IOMMU-device-for-page-table-allocation.patch
11. 0004-drm-msm-release-ARM-DMA-mapping-before-attaching-own.patch
12. 0008-ARM-dts-qcom-ifc6410-add-GPU-vddcx-regulator-supply.patch
EOF

    git -C "$IFC_LAYER_DST" add -A
    git -C "$IFC_LAYER_DST" diff --cached --check
    git -C "$IFC_LAYER_DST" commit -m \
        "meta-ifc6410: prepare Wrynose Linux 6.18 config baseline"

    source_new_env
    add_layer_once "$IFC_LAYER_DST"
    write_local_conf ifc6410
    bitbake-layers show-appends | tee "$LOG_DIR/show-appends-staged.txt"

    if grep -qE 'file://[^[:space:]"\\]+\.patch' "$new_append"; then
        die "Safety check failed: patches are unexpectedly enabled in $new_append"
    fi

    touch "$STATE_DIR/layer-staged"
    say "Layer staged with old patches disabled"
    printf 'Review: git -C %q show --stat\n' "$IFC_LAYER_DST"
    printf 'Next:   %s custom-build\n' "$0"
}

custom_build() {
    [[ -f "$STATE_DIR/layer-staged" ]] || die "Run stage-layer first."
    source_new_env
    add_layer_once "$IFC_LAYER_DST"
    write_local_conf ifc6410

    say "Validating custom provider and append"
    bitbake-layers show-layers | tee "$LOG_DIR/layers-custom.txt"
    bitbake-layers show-appends | tee "$LOG_DIR/appends-custom.txt"
    bitbake -e virtual/kernel |
        grep -E '^(MACHINE|PN|PV|S|B|SRCREV|KBUILD_DEFCONFIG|KERNEL_DEVICETREE|PREFERRED_PROVIDER_virtual/kernel)=' |
        tee "$LOG_DIR/kernel-selection-custom.txt"

    say "Building config/firmware-only IFC6410 kernel"
    bitbake -c clean virtual/kernel
    bitbake -c patch -f virtual/kernel 2>&1 | tee "$LOG_DIR/custom-patch.log"
    bitbake virtual/kernel 2>&1 | tee "$LOG_DIR/custom-kernel-build.log"

    local deploy=$BUILD_DIR/tmp/deploy/images/ifc6410
    if [[ -d "$deploy" ]]; then
        find "$deploy" -maxdepth 1 -type f \
            \( -name 'zImage*' -o -name '*ifc6410*.dtb' -o -name 'boot-*.img' -o -name 'modules-*.tgz' \) \
            -printf '%f\n' | sort | tee "$LOG_DIR/custom-artifacts.txt"
    else
        warn "Expected deploy directory not found yet: $deploy"
    fi

    touch "$STATE_DIR/custom-kernel.ok"
    say "Config/firmware-only custom kernel checkpoint passed"
    say "Do not enable all old patches together; the next phase is one patch plus one do_patch test at a time."
}

status_cmd() {
    say "Paths"
    printf 'OLD=%s\nNEW=%s\nBUILD_DIR=%s\n' "$OLD" "$NEW" "$BUILD_DIR"
    if [[ -d "$STATE_DIR" ]]; then
        say "Checkpoints"
        find "$STATE_DIR" -maxdepth 1 -type f -printf '%f\n' | sort
    fi
    if [[ -f "$NEW/revisions.txt" ]]; then
        say "Revisions"
        cat "$NEW/revisions.txt"
    fi
    if [[ -f "$CORE/oe-init-build-env" && -d "$BUILD_DIR/conf" ]]; then
        source_new_env
        say "Layers"
        bitbake-layers show-layers
        say "Kernel selection"
        bitbake -e virtual/kernel |
            grep -E '^(MACHINE|PN|PV|S|B|SRCREV|KBUILD_DEFCONFIG|KERNEL_DEVICETREE|PREFERRED_PROVIDER_virtual/kernel)='
    fi
}

all_cmd() {
    prepare
    stock_build
    stage_layer
    custom_build
}

case ${1:-help} in
    preflight)    preflight ;;
    archive)      archive_old ;;
    prepare)      prepare ;;
    stock-build)  stock_build ;;
    stage-layer)  stage_layer ;;
    custom-build) custom_build ;;
    status)       status_cmd ;;
    all)          all_cmd ;;
    help|-h|--help) usage ;;
    *) usage >&2; die "Unknown command: $1" ;;
esac
