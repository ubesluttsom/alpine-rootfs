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

# Use $config to decide what to do
if [ "$config" = "router" ]; then
    echo -e " ${GREEN}Configuring as router VM ... ${NC}"
    /root/router.sh
elif [ "$config" = "1" ]; then
    echo -e " ${GREEN}Configuring as VM 1 ... ${NC}"
    /root/vm1.sh
elif [ "$config" = "2" ]; then
    echo -e " ${GREEN}Configuring as VM 2 ... ${NC}"
    /root/vm2.sh
else
    echo -e " ${YELLOW}Unknown configuration. (\`vm=\` kernel parameter not in {router, 1, 2}.)${NC}"
    exit 0
fi

echo -e "${GREEN}VM init done!${NC}"
exit 0
