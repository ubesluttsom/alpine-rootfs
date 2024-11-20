#!/bin/sh

set -e

LATEST_MINI_ROOTFS=$(find . -name 'alpine-minirootfs-[0-9.]*-aarch64.tar.gz')
ROOTFS_DIR="rootfs"
KERNEL_MODULES="kernel-modules"
KERNEL_HEADERS="kernel-headers"
KERNEL_VERSION="6.7.0"
# CUSTOM_IPROUTE2="custom-iproute2"
ALPINE_SCRIPTS="alpine-scripts"
VM_INTERFACES="vm-interfaces"

if [ -d "$ROOTFS_DIR" ]; then
    echo "Directory '$ROOTFS_DIR' exists. Refusing to overwrite."
    exit 1
fi

echo "Extracting rootfs ... "
mkdir $ROOTFS_DIR
tar -xf $LATEST_MINI_ROOTFS --directory rootfs

echo "Patching with kernel modules ... "
mkdir -p $ROOTFS_DIR/lib/modules/
mv -v $KERNEL_MODULES/* $ROOTFS_DIR/lib/modules/

echo "Adding kernel headers ... "
mkdir -p $ROOTFS_DIR/usr/src/linux-$KERNEL_VERSION/
mv -v $KERNEL_HEADERS/* $ROOTFS_DIR/usr/src/linux-$KERNEL_VERSION/
chroot $ROOTFS_DIR ln -sfn /usr/src/linux-$KERNEL_VERSION /lib/modules/$KERNEL_VERSION/build

echo "Adding Alpine configuration scripts ... "
mv -v $ALPINE_SCRIPTS/* $ROOTFS_DIR/root/

echo "Adding neccessary packages ... "
cp /etc/resolv.conf $ROOTFS_DIR/etc/resolv.conf
chroot $ROOTFS_DIR apk add --no-cache \
        openrc busybox-mdev-openrc iptables agetty iperf3 make libelf coreutils dropbear tcpdump ethtool iproute2

# echo "Install custom iproute2 ... "
# mv -v $CUSTOM_IPROUTE2 $ROOTFS_DIR/root/
# chroot $ROOTFS_DIR sh -c "cd /root/$CUSTOM_IPROUTE2 && make install"

echo "Enable drivers and mounting of filesystem ... "
chroot $ROOTFS_DIR rc-update add mdev sysinit
chroot $ROOTFS_DIR rc-update add hwdrivers sysinit
chroot $ROOTFS_DIR rc-update add localmount boot

echo "Setting up serial TTY ... "
chroot $ROOTFS_DIR ln -s /etc/init.d/agetty /etc/init.d/agetty.ttyAMA0
sed -i -E 's/#(agetty_options=).*/\1"--autologin root --noclear"/' \
        $ROOTFS_DIR/etc/conf.d/agetty
chroot $ROOTFS_DIR rc-update add agetty.ttyAMA0 default
chroot $ROOTFS_DIR rm /etc/motd

echo "Configuring SSH (Dropbear) ..."
chroot $ROOTFS_DIR sh -c "echo 'DROPBEAR_OPTS=\"-s -g\"' >> /etc/conf.d/dropbear"

echo "Setting up SSH keys for VMs ... "
mkdir -p $ROOTFS_DIR/root/.ssh
mv vm_key.pub $ROOTFS_DIR/root/.ssh/authorized_keys
chmod 700 $ROOTFS_DIR/root/.ssh
chmod 600 $ROOTFS_DIR/root/.ssh/authorized_keys

# echo "Generate interfaces VMs ... "
# ./vm.py --generate
# ./vm.py --interfaces
# mv -v $VM_INTERFACES $ROOTFS_DIR/root/$VM_INTERFACES

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
