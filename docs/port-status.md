# Port status — Sailfish OS pipa

## Done (tree)

- [x] Project scaffold (dontbeevil model)
- [x] `droid-config-pipa` patterns + sparse (eglfs card1, mce gconf, RNDIS, display-on)
- [x] `kernel-adaptation-pipa` prebuilt packaging
- [x] `droid-hal-version-pipa`
- [x] `image-ci` kickstart + GitLab CI stub
- [x] Flash packer / flash.sh
- [x] Platform SDK Docker verify script

## Next on device

- [ ] Build adaptation RPMs in SDK
- [ ] `mic` rootfs → flash
- [ ] Lipstick/Silica UI
- [ ] Wi-Fi, audio, BT, sensors, camera

## Credentials / network

- USB RNDIS: `172.16.42.1`
- Developer mode / SSH after first boot (jolla-developer-mode in pattern)
