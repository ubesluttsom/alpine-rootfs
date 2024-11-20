#!/bin/sh

set -e

echo "Configuring Ethernet devices ..."
echo 'auto eth0
iface eth0 inet dhcp

auto eth1
iface eth1 inet static
      address 10.2.3.3
      netmask 255.255.255.0
      gateway 10.2.3.0' > /etc/network/interfaces

echo "Resetting network service ..."
rc-update add networking boot
rc-service networking restart
rc-update add dropbear
rc-service dropbear restart
hostname "vm3"

# Ping loop
ping_loop () {
    timeout=$1
    target_ip=$2
    echo "Pinging $target_ip until it responds..."
    while ! ping -c1 -W $timeout $target_ip &>/dev/null; do
        echo "Waiting for $target_ip to respond..."
        sleep 1
    done
    echo "$target_ip is up!"
}
ping_loop "10" "10.1.1.1"
ping_loop "10" "10.2.2.2"

/root/cong.sh lgc 10
# /root/qdisc.sh
