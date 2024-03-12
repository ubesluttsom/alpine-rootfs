#!/bin/sh

set -e

echo "Setting up PEP-DNA ..."

iptables -t mangle -N DIVERT
iptables -t mangle -A PREROUTING -p tcp -m socket -j DIVERT
iptables -t mangle -A DIVERT -j MARK --set-mark 1
iptables -t mangle -A DIVERT -j ACCEPT

ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100

iptables -t mangle -A PREROUTING -p tcp -j TPROXY --tproxy-mark 1 --on-port 9999

echo "Set sysctl variables to allow full transparency ..."
sysctl -w net.ipv4.conf.all.route_localnet=1
sysctl -w net.ipv4.ip_nonlocal_bind=1
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv4.conf.eth1.rp_filter=0

echo "Loading local PEP-DNA at the router node ..."
modprobe pepdna port=9999 mode=0

echo "Reseting network service ..."
rc-service networking restart
hostname pep-dna-router
