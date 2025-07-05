#!/bin/bash

cd /lib/modules
cp /mnt/nfs/sata-ssd/ssd-data/backup/ifc6410/github/poky/build/qcom-armv7a/artifacts/modules* .
tar xvf modules*.tgz
cd ./lib/modules
mv 6.6* /lib/modules
cd /lib/modules
rmdir /lib/modules/lib/modules
rmdir /lib/modules/lib
