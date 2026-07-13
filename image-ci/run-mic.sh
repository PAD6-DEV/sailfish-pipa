#!/bin/sh
set -eu
echo "Building Sailfish $RELEASE"
echo "Working directory $WORKING_DIRECTORY"

cd "$WORKING_DIRECTORY"

RELEASEMAJMIN=$(echo "$RELEASE" | cut -d '.' -f 1-2)

sudo zypper in -y kmod
sudo mic create fs --arch="$PORT_ARCH" \
  --tokenmap="ARCH:$PORT_ARCH,RELEASE:$RELEASE,RELEASEMAJMIN:$RELEASEMAJMIN,EXTRA_NAME:$EXTRA_NAME" \
  --record-pkgs=name,url \
  --outdir="sfe-$DEVICE-$RELEASE$EXTRA_NAME" \
  --pack-to="sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2" \
  "Jolla-@RELEASE@-$DEVICE-@ARCH@.ks"

# Require a real rootfs tarball
ls -lh "sfe-$DEVICE-$RELEASE$EXTRA_NAME"/*.tar.bz2
test -s "sfe-$DEVICE-$RELEASE$EXTRA_NAME/sfe-$DEVICE-$RELEASE$EXTRA_NAME.tar.bz2"
