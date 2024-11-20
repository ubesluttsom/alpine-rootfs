#!/bin/sh

# Delay between polls in seconds
DELAY=0.01

# Check if script should daemonize itself
if [ "$1" = "--daemon" ]; then
    shift  # Remove the first argument
    nohup "$0" "$@" > /dev/null 2>&1 &
    exit
fi

# Check if a filename is passed as an argument
if [ -n "$1" ]; then
    OUTPUT_FILE=$1
    exec > $OUTPUT_FILE  # Redirect standard output to the file
fi

# Continuous loop to poll and display the metrics
echo "time,source,destination,cwnd,mss,snd_wnd"
while true; do
ss -taoipnmO | awk '
/ESTAB&cwnd| mss/ {
    OFS=", ";

    # Get timestamp
    "date \"+%Y-%m-%dT%H:%M:%S.%3N\"" | getline timestamp;

    # Print the local and peer address with ports
    ip_and_port = $4 ", " $5;

    # Iterate through all fields to find cwnd and mss values
    for (i=1; i<=NF; i++) {
        if ($i ~ /^cwnd:/) {
            sub(/^cwnd:/, "", $i);
            cwnd = $i;
        }
        if ($i ~ /^mss:/) {
            sub(/^mss:/, "", $i);
            mss = $i;
        }
        if ($i ~ /^snd_wnd:/) {
            sub(/^snd_wnd:/, "", $i);
            snd_wnd = $i;
        }
    }

    # Print results
    print timestamp, ip_and_port, cwnd, mss, snd_wnd;

    # Reset variables for next line
    cwnd = ""; mss = ""; snd_wnd = ""; ip_and_port = "";
}'

# Wait for a specified delay before polling again
sleep $DELAY
done
