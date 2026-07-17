# qt5-qtmultimedia camerabin ResourceSet alloc fix

Temporary binary patch for `libgstcamerabin.so` (BSO v4l build).

Qt Multimedia allocates `sizeof(ResourcePolicy::ResourceSet)==24`, but
libresourceqt5's `ResourceSet` is larger. The undersized allocation corrupts
the heap and can abort jolla-camera in CamerabinResourcePolicy.

`patch-resourceset-alloc.sh` bumps the allocation at a known site from 24 to
256 bytes. Prefer a proper rebuild of qt5-qtmultimedia when available.
