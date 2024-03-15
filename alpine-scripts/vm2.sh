#!/bin/sh

set -e

echo "Configuring Ethernet devices ..."
echo 'auto eth1
iface eth1 inet static
      address 10.0.0.2
      netmask 255.255.255.0
      gateway 10.0.0.20' > /etc/network/interfaces

echo "Resetting network service ..."
rc-update add networking boot
rc-service networking restart
hostname "vm2"

# Ping loop
timeout=10
target_ip="10.0.0.1"
echo "Pinging $target_ip until it responds..."
while ! ping -c1 -W $timeout $target_ip &>/dev/null; do
    echo "Waiting for $target_ip to respond..."
    sleep 1
done
echo "$target_ip is up!"
