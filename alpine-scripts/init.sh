#!/bin/sh

set -e

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Read the command line arguments from the kernel
cmdline=$(cat /proc/cmdline)
for arg in $cmdline; do
    case "$arg" in
        vm=*)
            config="${arg#*=}"
            ;;
        *)
            # Ignore other arguments
            ;;
    esac
done

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

configure_vm () {
    while [ $# -gt 0 ]; do
        case "$1" in
            --router)
                router="true"
                ;;
            *)
                name=$1
                ;;
        esac
        shift 1
    done

    echo -e " ${GREEN}Configuring as ${name} ... ${NC}"

    echo "Configuring Ethernet devices ..."
    cp /root/vm-interfaces/${name} /etc/network/interfaces
    
    if [ "$router" = "true" ]; then
        echo "Set sysctl variables for routing ..."
        sysctl -w net.ipv4.conf.all.proxy_arp=1
        sysctl -w net.ipv4.ip_forward=1

        /root/qdisc.sh --shq 1 2
    fi

    echo "Resetting network service ..."
    rc-update add networking boot
    rc-service networking restart
    rc-update add dropbear
    rc-service dropbear restart
    hostname "${name}"

    # ping_loop "10" "10.1.1.1"

    /root/cong.sh lgc 10
}

# Use $config to decide what to do
case "$config" in
    [0-9])
        hostname "vm$config"
        ;;
    *)
        hostname "$config"
        ;;
esac

/root/reset-network.sh

echo -e "${GREEN}VM init done!${NC}"
exit 0
