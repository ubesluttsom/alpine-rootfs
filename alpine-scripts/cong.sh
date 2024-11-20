#!/bin/sh

set -e

CONGESTION_CONTROL="unset"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        lgc)
            if [ -z "$2" ]; then
                echo "Error: Missing argument for lgc_max_rate"
                echo "Usage: $0 lgc <lgc_max_rate>"
                exit 1
            fi
            CONGESTION_CONTROL="lgc"
            LGC_MAX_RATE="$2"
            shift 2
            ;;
        *)
            CONGESTION_CONTROL="$1"
            shift 1
            ;;
    esac
done

if [ "$CONGESTION_CONTROL" != "unset" ]; then
    echo "Setting congestion control ..."
    sysctl -w net.ipv4.tcp_congestion_control=$CONGESTION_CONTROL
    if [ "$CONGESTION_CONTROL" = "lgc" ]; then
        sysctl -w net.ipv4.lgc.lgc_max_rate=$LGC_MAX_RATE
    fi
    exit 0
fi

echo "Usage: $0 (lgc <lgc_max_rate> | <some other congestion control>)"
exit 1
