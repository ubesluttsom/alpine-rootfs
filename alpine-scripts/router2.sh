#!/bin/sh

set -e

echo "Configuring Ethernet devices ..."
echo 'auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
      address 10.2.1.0
      netmask 255.255.255.0

auto eth2
iface eth2 inet static
      address 10.2.2.0
      netmask 255.255.255.0

auto eth3
iface eth3 inet static
      address 10.2.3.0
      netmask 255.255.255.0' > /etc/network/interfaces

echo "Set sysctl variables for routing ..."
sysctl -w net.ipv4.conf.all.proxy_arp=1
sysctl -w net.ipv4.ip_forward=1

echo "Resetting network service ..."
rc-update add networking boot
rc-service networking restart
rc-update add dropbear
rc-service dropbear restart
hostname "router2"

echo "Setting up static IP table ..."
ip route add 10.1.0.0/16 via 10.2.1.0 dev eth1
ip route show

/root/cong.sh lgc 10
/root/qdisc.sh --shq 2
