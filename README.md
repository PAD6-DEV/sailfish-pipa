# Sailfish OS on Xiaomi Pad 6 (pipa)

Community port modeled on [sailfish-on-dontbeevil](https://github.com/sailfish-on-dontbeevil)
and [dont_be_evil-ci](https://gitlab.com/sailfishos-porters-ci/dont_be_evil-ci/).

**Native mainline** adaptation (mesa + eglfs), not Android hybris.

## Layout

| Path | Role |
|------|------|
| `droid-config-pipa/` | Device config, patterns, sparse overlays |
| `kernel-adaptation-pipa/` | Prebuilt kernel RPM |
| `droid-hal-version-pipa/` | Version / branding meta RPM |
| `image-ci/` | `mic` kickstart + CI |
| `flash/` | Pack rootfs → fastboot images |
| `repo/adaptation/` | Local RPM feed for mic |
| `docs/` | Port notes |

## Quick start

```bash
make sdk-pull sdk-verify
# build adaptation RPMs inside SDK, then:
make repo
cd image-ci && source root.env && source pipa/pipa.env
export WORKING_DIRECTORY=pipa && ./run-mic.sh
./flash/pack-rootfs.sh pipa/sfe-pipa-*/sfe-*.tar.bz2 ./flash/out
./flash/flash.sh ./flash/out
./scripts/bringup-check.sh
```

Default SFOS release: **5.0.0.77** (`image-ci/root.env`).


## CI

GitHub Actions (`.github/workflows/build-rootfs.yml`) builds on
`coderus/sailfishos-platform-sdk-base:4.6.0.13` (same as dont_be_evil-ci).

```bash
# after push
# Actions → Build Sailfish pipa rootfs → download sailfish-pipa-rootfs artifact
```
