#!/bin/sh

set -e

# Size of the disk image in GB
IMG_SIZE=2048

ROOTFS_DIR="rootfs"
ROOTFS_IMG="rootfs.img"

if [ -f "$ROOTFS_IMG" ]; then
    echo "'$ROOTFS_IMG' exists. Refusing to overwrite."
    exit 1
fi

echo "Creating disk image ... "
dd if=/dev/zero of=$ROOTFS_IMG bs=1M count=$IMG_SIZE
mkfs.ext4 -d $ROOTFS_DIR -F -L rootfs $ROOTFS_IMG

echo "[Disk image created: $ROOTFS_IMG]"
