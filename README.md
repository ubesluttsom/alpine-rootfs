# Minimal Alpine Linux rootfs

Make a *minimal* Alpine Linux system image. Do `./docker.sh` to build. Dependant on `../linux/modules/lib/modules/` existing. Note the relative path.

The Docker-container script executes, in order:

* [`./get-alpine-rootfs.sh`](./get-alpine-rootfs.sh)
* [`./patch-alpine-rootfs.sh`](./patch-alpine-rootfs.sh)
* [`./create-alpine-rootfs.sh`](./create-alpine-rootfs.sh)

and spits out a `rootfs.img`.

The [`alpine-scripts/`](alpine-scripts/) directory contains scripts to be put inside the file system image.

## `vm.py` script

There is a `vm.py` script that should automatically create the right configuration files for the different VMs in addition to the correct QEMU invocations. It tries to create IP and port assignments. Do a `./vm.py` to see how to use it. It is dependent on a `vms.json` configuration file, which describes the network topology.
