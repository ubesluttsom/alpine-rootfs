#!/bin/sh

set -e

if [ $# -eq 0 ]; then
    iperf3 --server
    exit 1
fi

for port in $(seq 1001 $(expr 1000 + $1))
do
    iperf3 --server --daemon --port $port
    echo "iperf3 --server --daemon --port $port"
done
