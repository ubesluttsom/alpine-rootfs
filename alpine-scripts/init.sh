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
    none)
        hostname "none"
        ./root/reset-network.sh
        ;;
    [0-9])
        hostname "vm$config"
        ./root/reset-network.sh
        ;;
    # router1|router2)
    #     configure_vm --router $config
    #     ;;
    # vm1|vm2|vm3)
    #     configure_vm $config
    #     ;;
    # *)
    #     echo -e " ${YELLOW}Unknown configuration. (\`vm=\` kernel parameter not {router1, router2, vm1, vm2, vm3, [0-1]}.)${NC}"
    #     exit 0
    *)
        hostname "$config"
        ./root/reset-network.sh
        ;;
esac

echo -e "${GREEN}VM init done!${NC}"
exit 0
