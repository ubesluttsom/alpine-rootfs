#!/bin/sh

set -e

echo "Setting up ShQ ..."

# Delete the existing qdisc settings on the device
tc qdisc del dev eth1 root 2>/dev/null || true;
tc qdisc del dev eth2 root 2>/dev/null || true;

# Add ShQ
tc qdisc add dev eth1 root handle 11: shq limit 1000 interval 10ms maxp 0.8 alpha 0.95 bandwidth 10mbps ecn;

# Display configuration
tc qdisc show
