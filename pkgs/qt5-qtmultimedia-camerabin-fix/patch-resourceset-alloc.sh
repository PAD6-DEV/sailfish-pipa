#!/bin/sh
# qt5-qtmultimedia (BSO v4l) allocates sizeof(ResourcePolicy::ResourceSet)==24
# but libresourceqt5's ResourceSet is larger; the undersized new[] corrupts the
# heap and jolla-camera aborts in CamerabinResourcePolicy with
# "double free or corruption" / QString teardown after ResourceSet("camera").
# Bump the allocation to 256 bytes at the known site in libgstcamerabin.so.
set -e
SO=/usr/lib64/qt5/plugins/mediaservice/libgstcamerabin.so
BAK=${SO}.bak
OFF=0x2ed8c
# mov x0,#0x18
OLD=000380d2
# mov x0,#0x100
NEW=002080d2

if [ ! -f "$BAK" ]; then
  cp -a "$SO" "$BAK"
fi
python3 - <<PY
import struct
path="$SO"
bak="$BAK"
off=$OFF
data=bytearray(open(bak,"rb").read())
assert data[off:off+4]==bytes.fromhex("$OLD"), data[off:off+4].hex()
struct.pack_into("<I", data, off, 0xd2802000)
open(path,"wb").write(data)
print("patched", path, "ResourceSet alloc 24->256")
PY
chmod 755 "$SO"
