# Use Alpine Linux as the base image
FROM alpine:latest

# Install the required packages
RUN apk add --no-cache e2fsprogs curl tar

# Set the working directory
WORKDIR /build

# Copy the scripts and necessary files into the image
COPY get-alpine-rootfs.sh patch-alpine-rootfs.sh create-alpine-rootfs.sh ./
COPY kernel-modules ./kernel-modules
COPY kernel-headers ./kernel-headers
COPY alpine-scripts ./alpine-scripts

# Execute the scripts to set up the environment
RUN sh get-alpine-rootfs.sh && \
    sh patch-alpine-rootfs.sh && \
    sh create-alpine-rootfs.sh

# Set the default command to output the bootable image
# CMD ["cat", "/build/rootfs.img"]
