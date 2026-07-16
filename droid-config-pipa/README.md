# droid-config-pipa

Sailfish OS configuration for Xiaomi Pad 6 (`pipa`).

Native mainline adaptation following
[sailfish-on-dontbeevil/droid-config-pinetab2](https://github.com/sailfish-on-dontbeevil/droid-config-pinetab2):

- `arm_native_default.pa` + native `xpolicy.conf`
- ConnMan `main-native.conf` via `CONNMAN_ARGS`
- `wlan-module-load.service` + `setup-configfs.service` + usb-moded
- `start-bluetooth-adapter.service` + `setup-bt-address.service`

Device-only pieces (sm8250 UCM, eglfs KMS, hexagon/fastrpc) stay pipa-local.
Rockchip/modem/PinePhone files are not carried over.

## Build (Platform SDK)

```bash
cd droid-config-pipa
mb2 -t SailfishOS-...-aarch64 build
```

See `/home/ayman/sailfish-pipa/docs/` for the full port workflow.
