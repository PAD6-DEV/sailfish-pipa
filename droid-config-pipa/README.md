# Configuration package for Xiaomi Pad 6 (pipa) Sailfish OS
# Native mainline adaptation (mesa/eglfs), modeled on sailfish-on-dontbeevil.

## Mer / local OBS
Packages are intended for:
`nemo:devel:hw:xiaomi:pipa` (or a local file repo during bring-up).

## Build (Platform SDK)
```bash
cd droid-config-pipa
mb2 -t SailfishOS-...-aarch64 build
```

See `/home/ayman/sailfish-pipa/docs/` for the full port workflow.
