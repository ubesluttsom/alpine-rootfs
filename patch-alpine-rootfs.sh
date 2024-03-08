#!/bin/sh

set -e

LATEST_MINI_ROOTFS=$(find . -name 'alpine-minirootfs-[0-9.]*-aarch64.tar.gz')
ROOTFS_DIR="rootfs/"
KERNEL_MODULES="kernel-modules/"
ALPINE_SCRIPTS="alpine-scripts/"

if [ -d "$ROOTFS_DIR" ]; then
    echo "Directory '$ROOTFS_DIR' exists. Refusing to overwrite."
    exit 1
fi

echo "Extracting rootfs ... "
mkdir $ROOTFS_DIR
tar -xf $LATEST_MINI_ROOTFS --directory rootfs

echo "Patching with kernel modules ... "
cp -R $KERNEL_MODULES $ROOTFS_DIR/lib/modules/
cp -R $ALPINE_SCRIPTS/* $ROOTFS_DIR/root/

echo "Adding neccessary packages ... "
cp /etc/resolv.conf $ROOTFS_DIR/etc/resolv.conf
chroot $ROOTFS_DIR apk add --no-cache \
        openrc busybox-mdev-openrc agetty iperf3

echo "Enable drivers and mounting of filesystem ... "
chroot $ROOTFS_DIR rc-update add mdev sysinit
chroot $ROOTFS_DIR rc-update add hwdrivers sysinit
chroot $ROOTFS_DIR rc-update add localmount boot

echo "Setting up serial TTY ... "
chroot $ROOTFS_DIR ln -s /etc/init.d/agetty /etc/init.d/agetty.ttyAMA0
chroot $ROOTFS_DIR sed -i -E 's/#(agetty_options=).*/\1"--autologin root --noclear"/' /etc/conf.d/agetty
chroot $ROOTFS_DIR rc-update add agetty.ttyAMA0 default
chroot $ROOTFS_DIR rm /etc/motd

echo "Adding VM configuration service ... "
echo '#!/sbin/openrc-run
description="Custom VM configuration script"

service_type="oneshot"
command="/root/init.sh"
command_args=""
command_background="false"

depend() {
    need localmount
    after bootmisc
    before agetty.ttyAMA0
}' > $ROOTFS_DIR/etc/init.d/vm-config
chmod +x $ROOTFS_DIR/etc/init.d/vm-config
chroot $ROOTFS_DIR rc-update add vm-config default

echo "[Patching done: $ROOTFS_DIR]"
