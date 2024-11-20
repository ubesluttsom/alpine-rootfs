#!/bin/sh

sysctl -w net.ipv4.tcp_syn_retries=1
sysctl -w net.ipv4.tcp_syncookies=0
sysctl -w net.ipv4.conf.all.route_localnet=1
sysctl -w net.ipv4.ip_nonlocal_bind=1
