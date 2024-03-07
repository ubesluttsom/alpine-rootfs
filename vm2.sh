#!/bin/sh

set -e

echo "Configuring Ethernet devices ..."
echo 'auto eth1
iface eth1 inet static
      address 10.0.0.2
      netmask 255.255.255.0
      gateway 10.0.0.20' > /etc/network/interfaces

echo "Reseting network service ..."
rc-update add networking boot
rc-service networking restart
