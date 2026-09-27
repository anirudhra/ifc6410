#!/usr/bin/env bash
set -eu

TOP=/mnt/pve-sata-ssd/ssd-data/backup/ifc6410/github/poky6.0
LAYER=$TOP/meta-ifc6410
QCOM=$TOP/meta-qcom
BUILD=$TOP/build/qcom-armv7a
ROOT=/mnt/pve-sata-ssd/ssd-data/backup/ifc6410/patch_backup/yocto6.0

STAMP=$(date +%Y%m%d-%H%M%S)
OUT=$ROOT/meta-ifc6410-$STAMP

mkdir -p "$OUT/meta-ifc6410/patches"
mkdir -p "$OUT/meta-ifc6410/untracked"
mkdir -p "$OUT/meta-qcom"
mkdir -p "$OUT/build-config"

test -d "$LAYER/.git"
test -d "$QCOM"
test -d "$BUILD"

cd "$LAYER"

git status --short --untracked-files=all > "$OUT/meta-ifc6410/status.txt"
git diff --binary > "$OUT/meta-ifc6410/working-tree.patch"
git diff --cached --binary > "$OUT/meta-ifc6410/staged.patch"
git log --oneline --decorate -n 100 > "$OUT/meta-ifc6410/log.txt"
git branch -avv > "$OUT/meta-ifc6410/branches.txt"
git remote -v > "$OUT/meta-ifc6410/remotes.txt"
git rev-parse HEAD > "$OUT/meta-ifc6410/head.txt"

git ls-files --others --exclude-standard -z > "$OUT/meta-ifc6410/untracked-files.nul"

if test -s "$OUT/meta-ifc6410/untracked-files.nul"; then
    tar --null \
        --files-from="$OUT/meta-ifc6410/untracked-files.nul" \
        -czf "$OUT/meta-ifc6410/untracked/untracked-files.tar.gz"
fi

git bundle create "$OUT/meta-ifc6410/meta-ifc6410-$STAMP.bundle" --all
git bundle verify "$OUT/meta-ifc6410/meta-ifc6410-$STAMP.bundle" \
    > "$OUT/meta-ifc6410/bundle-verify.txt"

git format-patch --binary \
    --output-directory "$OUT/meta-ifc6410/patches" \
    -1 HEAD

git archive \
    --format=tar.gz \
    --prefix=meta-ifc6410-$STAMP/ \
    --output="$OUT/meta-ifc6410/meta-ifc6410-$STAMP-source.tar.gz" \
    HEAD


cd "$QCOM"

git status --short --untracked-files=all \
    > "$OUT/meta-qcom/status.txt"

git rev-parse HEAD \
    > "$OUT/meta-qcom/head.txt"

git branch --show-current \
    > "$OUT/meta-qcom/branch.txt" || true

git remote -v \
    > "$OUT/meta-qcom/remotes.txt"

git describe --always --dirty --tags \
    > "$OUT/meta-qcom/describe.txt" || true

cp -a "$BUILD/conf" "$OUT/build-config/"

cp -a "$ROOT/backup-meta-ifc6410.sh" "$OUT/"

cat > "$OUT/README.txt" <<EOF
IFC6410 Yocto backup
Timestamp: $STAMP

Source:
  $LAYER

Parallel layer:
  $QCOM

Build:
  $BUILD

Contents:
  meta-ifc6410/working-tree.patch
  meta-ifc6410/staged.patch
  meta-ifc6410/untracked/
  meta-ifc6410/patches/
  meta-ifc6410/*.bundle
  meta-qcom/
  build-config/conf/
EOF

cd "$ROOT"
tar -czf "meta-ifc6410-$STAMP.tar.gz" "meta-ifc6410-$STAMP"

sha256sum "meta-ifc6410-$STAMP.tar.gz" > "meta-ifc6410-$STAMP.tar.gz.sha256"

echo "Backup complete:"
echo "$OUT"
echo "$ROOT/meta-ifc6410-$STAMP.tar.gz"

