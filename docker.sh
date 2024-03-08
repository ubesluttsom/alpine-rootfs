#!/bin/sh

set -e

ROOTFS_IMG="rootfs.img"
KERNEL_MODULES="../linux/modules/lib/modules"

if [ -f "$ROOTFS_IMG" ]; then
    echo "Image '$ROOTFS_IMG' exists. Refusing to overwrite."
    exit 1
fi

if [ ! -d "$KERNEL_MODULES" ]; then
    echo "Directory '$KERNEL_MODULES' does not exist."
    exit 1
fi

mkdir -p kernel-modules
cp -R $KERNEL_MODULES/ ./kernel-modules

docker build -t alpine-rootfs .
docker create --name dummy alpine-rootfs
docker cp dummy:/build/$ROOTFS_IMG $ROOTFS_IMG
docker rm dummy
