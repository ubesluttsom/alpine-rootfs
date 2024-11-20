#!/bin/sh

echo "Configuring Ethernet devices ..."
echo '# /etc/network/interfaces
auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet dhcp

auto eth2
iface eth2 inet dhcp

auto eth3
iface eth3 inet dhcp
' > /etc/network/interfaces

echo "# /etc/udhcpc/udhcpc.conf
hostname=`hostname`
" > /etc/udhcpc/udhcpc.conf

echo "Reseting network service ..."
rc-update add networking boot
rc-update add dropbear
rc-service networking restart
rc-service dropbear restart
