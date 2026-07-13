# CI build

GitHub Actions workflow builds the Sailfish rootfs the same way as Pine dont_be_evil-ci:

1. Pull Platform SDK container
2. Build adaptation RPMs into `repo/adaptation`
3. `mic create fs` from `image-ci/pipa/Jolla-@RELEASE@-pipa-@ARCH@.ks`
4. Upload `sfe-pipa-*.tar.bz2` (+ optional flash raws)

Repo: `PAD6-DEV/sailfish-pipa`
