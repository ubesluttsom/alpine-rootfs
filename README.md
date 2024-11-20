# Minimal Alpine Linux rootfs

Make a *minimal* Alpine Linux system image. Do `./docker.sh` to build. Dependant on `../linux/modules/lib/modules/` existing. Note the relative path.

The Docker-container script executes, in order:

* [`./get-alpine-rootfs.sh`](./get-alpine-rootfs.sh)
* [`./patch-alpine-rootfs.sh`](./patch-alpine-rootfs.sh)
* [`./create-alpine-rootfs.sh`](./create-alpine-rootfs.sh)

and spits out a `rootfs.img`.

The [`alpine-scripts/`](alpine-scripts/) directory contains scripts to be put inside the file system image.
