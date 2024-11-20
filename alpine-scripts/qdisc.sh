#!/bin/sh

set -e

# Default values
NETEM_DELAY="20ms" # Default network emulation delay
TOTAL_DELAY="100ms"
BANDWIDTH_CAP="500" # Mbps. Default link bandwidth cap.
SHQ="false"

echo "Setting up qdiscs ..."

# Function to clear existing qdisc configurations
clear_interface () {
    # Delete the existing qdisc settings on the device
    tc qdisc del dev eth$i root 2>/dev/null || true;
}

# Function to add the experimental 'shq' qdisc
shq () {
    i=$1
    parent=$2
    tc qdisc add dev eth$i $parent shq limit 1000 interval ${TOTAL_DELAY} maxp 0.8 alpha 0.95 bandwidth ${BANDWIDTH_CAP}mbps ecn;
}

# Function to configure the interface
interface () {
    for i in $(seq $1 $2)
    do
        clear_interface $i

        # Add a netem qdisc to introduce a delay
        tc qdisc add dev eth$i root handle 2: netem delay ${NETEM_DELAY};

        # Add an htb qdisc as a parent for bandwidth management
        tc qdisc add dev eth$i parent 2: handle 3: htb default 10;

        # Add a class under the htb qdisc for rate control
        tc class add dev eth$i parent 3: classid 3:10 htb rate ${BANDWIDTH_CAP}Mbit;

        if [ "$SHQ" = "true" ]; then
            # Add ShQ
            shq $i "parent 3:10 handle 30:"
        else
            # Add fq_codel for queue management
            tc qdisc add dev eth$i parent 3:10 handle 30: fq_codel;
        fi
    done
}

# Parse arguments to optionally set network delay
while [ $# -gt 0 ]; do
    case "$1" in
        --delay)
            NETEM_DELAY="$2"
            shift 2
            ;;
        --bandwidth)
            BANDWIDTH_CAP="$2"
            shift 2
            ;;
        --clear)
            echo "Clearing qdiscs ..."
            for i in $(seq $2)
            do
                clear_interface $i
            done
            tc qdisc show
            exit 0
            ;;
        --shq)
            echo "(With ShQ ...)"
            SHQ="true"
            shift 1
            ;;
        *)
            interface $1 $2
            tc qdisc show
            exit 0
            ;;
    esac
done

echo "Usage: $0 [--delay <ms>] [--bandwidth <mbps>] [--clear] [--shq] <first eth> <last eth>"
exit 1
