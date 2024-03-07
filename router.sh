#!/bin/sh

set -e

echo "Configuring Ethernet devices ..."
echo 'auto eth1
iface eth1 inet static
      address 10.0.0.10
      netmask 255.255.255.0

auto eth2
iface eth2 inet static
      address 10.0.0.20
      netmask 255.255.255.0' > /etc/network/interfaces

echo "Set sysctl variables for routing ..."
sysctl -w net.ipv4.conf.all.proxy_arp=1
sysctl -w net.ipv4.ip_forward=1

echo "Reseting network service ..."
rc-update add networking boot
rc-service networking restart

echo "Setting up static IP table ..."
ip route add 10.0.0.1/32 dev eth1
ip route add 10.0.0.2/32 dev eth2
ip route show
