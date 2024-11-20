# Alpine VM configuration scripts

These are used inside Alpine VMs to properly configure them for the test setup used for my thesis.

* [`init.sh`](init.sh) is always executed after boot, and parses a custom kernel parameter, `vm=...`. For now it only calls `reset-network.sh`.
* [`reset-network.sh`](reset-network.sh) does basic configuration of network interfaces and enables SSH.
