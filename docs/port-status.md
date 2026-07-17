# Port status — Sailfish OS pipa

Repo: https://github.com/PAD6-DEV/sailfish-pipa

## Done

- [x] Project scaffold (dontbeevil model)
- [x] `droid-config-pipa` + bootstrap RPMs for CI
- [x] `kernel-adaptation-pipa` (placeholder until real Image staged)
- [x] GitHub Actions mic rootfs on Platform SDK Docker
- [x] CI artifact ~700MB+ `sailfish-pipa-rootfs`

## Sensors

- [x] Persist mount + `hexagonrpcd-sdsp` for SSC registry
- [x] Package `libssc` for adaptation repo (userspace SSC / SUID)
- [x] `sensorfw-qt5-libssc` accelerometer adaptor + primaryuse.conf wiring
- [ ] Validate orientation / CSD on device after publishing adaptor RPM

## Next on device

- [ ] Flash CI artifact + silicium
- [ ] Lipstick/Silica + display
- [ ] Wi-Fi, audio, BT, sensors, camera
- [ ] Replace placeholder kernel with pipa-pkgs Image
