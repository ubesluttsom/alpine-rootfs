#!/bin/sh

set -e

ROOTFS_IMG="rootfs.img"
KERNEL_MODULES="../linux/modules/lib/modules"
KERNEL_HEADERS="../linux/headers"
CUSTOM_IPROUTE2="../iproute2"
VM_KEY="vm_key"
VM_KEY_PUB="vm_key_pub"

if [ -f "$ROOTFS_IMG" ]; then
    echo "Image '$ROOTFS_IMG' exists. Refusing to overwrite."
    exit 1
fi

if [ ! -d "$KERNEL_MODULES" ]; then
    echo "Directory '$KERNEL_MODULES' does not exist."
    exit 1
fi

if [ ! -d "$KERNEL_HEADERS" ]; then
    echo "Directory '$KERNEL_HEADERS' does not exist."
    exit 1
fi

if [ ! -d "$CUSTOM_IPROUTE2" ]; then
    echo "Directory '$CUSTOM_IPROUTE2' does not exist."
    exit 1
fi

mkdir -p kernel-modules
mkdir -p kernel-headers
cp -R $KERNEL_MODULES/ ./kernel-modules
cp -R $KERNEL_HEADERS/ ./kernel-headers
rsync -a --exclude='.git' $CUSTOM_IPROUTE2/ ./custom-iproute2

if [ ! -f "$VM_KEY" ]; then
    echo "Generating VM key pair."
    rm $VM_KEY
    rm $VM_KEY_PUB
    ssh-keygen -t rsa -b 2048 -f vm_key -N ""
else
    echo "VM key already exists. Skipping creation."
fi

# if which podman &> /dev/null
if 0;
then
    DOCKER_CMD="podman"
else
    DOCKER_CMD="docker"
fi

$DOCKER_CMD build --no-cache -t alpine-rootfs .
$DOCKER_CMD create --name dummy alpine-rootfs
$DOCKER_CMD cp dummy:/build/$ROOTFS_IMG .
$DOCKER_CMD rm dummy
