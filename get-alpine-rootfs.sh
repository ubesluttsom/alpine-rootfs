#!/bin/sh

set -e

# URL where the mini rootfs releases can be found
BASE_URL="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/aarch64"

echo "Fetch the latest mini rootfs release name ... "
LATEST_MINI_ROOTFS=$(\
        curl -s $BASE_URL/ \
        | grep -o 'alpine-minirootfs-[0-9.]*-aarch64.tar.gz' \
        | sort -V \
        | tail -n 1 \
)

if [ -z "$LATEST_MINI_ROOTFS" ]; then
    echo "Failed to find the latest Alpine Linux mini rootfs release."
    exit 1
fi

# Construct the download URL
DOWNLOAD_URL="$BASE_URL/$LATEST_MINI_ROOTFS"

# Download the latest mini rootfs
echo "Downloading $LATEST_MINI_ROOTFS ..."
curl -O $DOWNLOAD_URL

echo "[Download completed: $LATEST_MINI_ROOTFS]"
