# pipa adaptation packages (zypper)

Built into GitHub Pages adaptation repo:

`https://pad6-dev.github.io/sailfish-pipa/adaptation/`

| Package | Role |
|---------|------|
| `droid-config-pipa` | sparse overlays (UCM, USB, wifi, sensors conf) |
| `kernel-adaptation-pipa` | kernel placeholder / staged Image |
| `patterns-sailfish-device-configuration-pipa` | pull in device stack |
| `pipa-qcom-userspace` | qrtr, pd-mapper, tqftpserv |
| `pipa-hexagonrpc` | hexagonrpcd + libhexagonrpc |
| `firmware-pipa` | GPU/DSP/touch/WiFi/BT firmware |

## On device

```bash
ssu ar adaptation-xiaomi-pipa https://pad6-dev.github.io/sailfish-pipa/adaptation/
zypper ref adaptation-xiaomi-pipa
zypper in patterns-sailfish-device-configuration-pipa \
  pipa-qcom-userspace pipa-hexagonrpc firmware-pipa
```

## Build locally

```bash
# noarch adaptation RPMs (SDK base)
./bootstrap/build-rpms.sh

# aarch64 userspace (full Platform SDK docker)
./pkgs/pipa-qcom-userspace/build-in-sdk.sh
./pkgs/pipa-hexagonrpc/build-in-sdk.sh

# firmware RPM
./firmware-pipa/build-firmware-tarball.sh
./pkgs/firmware-pipa/pack-rpm.sh
```
