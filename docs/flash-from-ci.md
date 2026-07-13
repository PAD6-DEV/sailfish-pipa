# Flash Sailfish OS from CI artifacts

1. Download **sailfish-pipa-rootfs** from the latest green run:
   https://github.com/PAD6-DEV/sailfish-pipa/actions
2. Unpack the zip; locate `sfe-pipa-*.tar.bz2` (and `flash/out/sfos_*.raw` if present).
3. Pack if needed:
   ```bash
   ./flash/pack-rootfs.sh path/to/sfe-pipa-*.tar.bz2 ./flash/out
   ```
4. Copy `silicium.img` (+ ESP if you use one) into `flash/out/`.
5. Boot tablet to fastboot, then:
   ```bash
   ./flash/flash.sh ./flash/out
   ```
6. After boot, USB RNDIS → `172.16.42.1`, then:
   ```bash
   ./scripts/bringup-check.sh
   ```
