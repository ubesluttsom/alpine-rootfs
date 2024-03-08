#!/bin/sh

echo "Configuring Ethernet devices ..."
echo 'auto eth0
iface eth0 inet dhcp' > /etc/network/interfaces

echo "Reseting network service ..."
rc-update add networking boot
rc-service networking restart
