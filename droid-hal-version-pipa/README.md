# droid-hal-version-pipa

Sailfish OS version / branding meta-package for Xiaomi Pad 6.

Ships `/etc/hw-release` (`MER_HA_DEVICE=pipa`, vendor/pretty name) so SSU
and the UI know the device model instead of `UNKNOWN`.

Built by `bootstrap/build-rpms.sh` (with `--nodeps` locally) and required by:
- `patterns-sailfish-device-adaptation-pipa`
- `patterns-sailfish-device-configuration-pipa` (bootstrap mic pattern)
- `adaptation-pipa.ini` SSU feature package list
- `ha.check` systemCheck

Uses `droid-hal-version.inc` with `native_build 1`.
