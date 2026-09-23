#!/bin/bash

cd /mnt/pve-sata-ssd/ssd-data/backup/ifc6410/github/poky/build/qcom-armv7a

CFG_FILE="../../meta-ifc6410/recipes-kernel/linux/files/ifc6410.cfg"
DOT_CONFIG=$(ls -1 tmp/work/qcom_armv7a-poky-linux-gnueabi/linux-linaro-qcomlt/6.6*/build/.config | head -n 1)

echo "=== CHECKING SYMBOLS FROM $(basename $CFG_FILE) ==="
while IFS='=' read -r key val || [ -n "$key" ]; do
    # Skip comments and blank lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    key=$(echo "$key" | xargs)

    # Search for the key in .config
    match=$(grep -E "^(${key}=|# ${key} is not set)" "$DOT_CONFIG" 2>/dev/null)
    if [ -z "$match" ]; then
        echo -e "\e[31m[MISSING/DROPPED]\e[0m $key (Not found in .config at all)"
    elif [[ "$match" =~ "is not set" ]]; then
        echo -e "\e[33m[DISABLED]\e[0m $match"
    else
        echo -e "\e[32m[APPLIED]\e[0m  $match"
    fi
done < "$CFG_FILE"

